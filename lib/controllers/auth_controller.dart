// ============================================================
// auth_controller.dart — lib/controllers/auth_controller.dart
// ✅ v2 : synchronise managedSchools depuis Firestore au login
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'dart:convert';
import '../services/db_service.dart';
import '../models/teachers.dart';
import '../utils/security_helper.dart';
import '../services/firestore_service.dart';
import '../services/sync_engine.dart';
import '../services/session_service.dart';

class AuthController {
  static final _firestore = FirebaseFirestore.instance;
  static final _fbAuth = fb.FirebaseAuth.instance;

  // ═══════════════════════════════════════════════════════
  //  REGISTER
  // ═══════════════════════════════════════════════════════
  static Future<RegisterResult> register(Teacher teacher) async {
    try {
      final plainPassword = teacher.passwordHash;
      final passwordHash = SecurityHelper.hashPassword(plainPassword);

      try {
        final cred = await _fbAuth.createUserWithEmailAndPassword(
          email: teacher.email,
          password: plainPassword,
        );
        await cred.user?.sendEmailVerification();
      } on fb.FirebaseAuthException catch (e) {
        switch (e.code) {
          case 'email-already-in-use':
            return RegisterResult.emailAlreadyUsed;
          case 'weak-password':
            return RegisterResult.weakPassword;
          case 'invalid-email':
            return RegisterResult.invalidEmail;
          default:
            print('ℹ️ Firebase Auth hors ligne: ${e.code}');
        }
      }

      final now = DateTime.now().toIso8601String();
      teacher.passwordHash = passwordHash;
      teacher.createdAt = now;
      teacher.updatedAt = now;
      teacher.synced = 0;
      teacher.isActive = 1;
      teacher.deleted = 0;

      final success = await DBService.insertTeacher(teacher);
      if (!success) return RegisterResult.emailAlreadyUsed;

      final saved = await DBService.login(
        email: teacher.email,
        passwordHash: passwordHash,
      );
      if (saved != null) await _syncNewTeacher(saved);

      return RegisterResult.success;
    } catch (e) {
      print('🔥 Erreur register: $e');
      return RegisterResult.error;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  SYNC INSCRIPTION → FIRESTORE (retry x3)
  // ═══════════════════════════════════════════════════════
  static Future<void> _syncNewTeacher(Teacher teacher) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await FirestoreService.upsertTeacher(teacher);
        final db = await DBService.database;
        await db.update(
          'teachers',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [teacher.id],
        );
        print('✅ Nouveau prof synced vers Firestore (tentative $attempt)');
        return;
      } catch (e) {
        print('⚠️ Sync tentative $attempt/$maxRetries : $e');
        if (attempt < maxRetries)
          await Future.delayed(Duration(seconds: attempt));
      }
    }
    print('ℹ️ Sync différée — sera envoyée au prochain lancement');
  }

  // ═══════════════════════════════════════════════════════
  //  LOGIN
  // ═══════════════════════════════════════════════════════
  static Future<LoginResult> login({
    required String email,
    required String password, // EN CLAIR pour Firebase
    required String passwordHash, // SHA-256 pour SQLite
  }) async {
    // 1️⃣ FIREBASE AUTH
    bool firebaseOk = false;
    try {
      final cred = await _fbAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser != null && !fbUser.emailVerified) {
        await _fbAuth.signOut();
        return LoginResult(teacher: null, error: 'email_not_verified');
      }
      firebaseOk = true;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        print('❌ Firebase Auth : ${e.code}');
      } else {
        print('ℹ️ Firebase hors ligne: ${e.code}');
      }
    } catch (e) {
      print('ℹ️ Pas de réseau: $e');
    }

    // 2️⃣ SQLITE LOCAL
    Teacher? teacher = await DBService.login(
      email: email,
      passwordHash: passwordHash,
    );

    // Cas reset password
    if (teacher == null && firebaseOk) {
      print('🔄 Reset password détecté → mise à jour SQLite');
      await DBService.updatePasswordHash(
        email: email,
        newPasswordHash: passwordHash,
      );
      teacher = await DBService.getTeacherByEmail(email);
    }

    if (teacher == null) {
      return LoginResult(
        teacher: null,
        error: 'Email ou mot de passe incorrect',
      );
    }

    // 3️⃣ SYNC DEPUIS FIRESTORE : rôle + managedSchools
    teacher = await _syncFromFirestore(teacher) ?? teacher;

    // 4️⃣ SESSION + SYNC
    SessionService.login(teacher);
    _syncAfterLogin(teacher);

    return LoginResult(teacher: teacher);
  }

  // ═══════════════════════════════════════════════════════
  //  SYNC RÔLE + MANAGED_SCHOOLS DEPUIS FIRESTORE
  //  Firestore = source de vérité pour rôle et écoles gérées
  // ═══════════════════════════════════════════════════════
  static Future<Teacher?> _syncFromFirestore(Teacher teacher) async {
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc('teacher_${teacher.id}')
          .get();

      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final remoteRole = data['role'] as String? ?? teacher.role;
      bool changed = false;

      // ── Sync rôle ────────────────────────────────────────
      if (remoteRole != teacher.role) {
        changed = true;
        print('✅ Rôle sync depuis Firestore: $remoteRole');
      }

      // ── Sync managedSchools ──────────────────────────────
      List<Map<String, String>> remoteManagedSchools = [];
      try {
        final rawList = data['managed_schools'];
        if (rawList is List) {
          remoteManagedSchools = rawList
              .map<Map<String, String>>(
                (e) => {
                  'name': (e['name'] ?? '').toString(),
                  'city': (e['city'] ?? '').toString(),
                },
              )
              .toList();
        }
      } catch (_) {}

      // Comparer avec SQLite
      final localSchools = teacher.managedSchools;
      final localJson = jsonEncode(localSchools);
      final remoteJson = jsonEncode(remoteManagedSchools);

      if (localJson != remoteJson) {
        changed = true;
        print(
          '✅ managedSchools sync depuis Firestore: ${remoteManagedSchools.length} école(s)',
        );
      }

      if (changed) {
        // Mettre à jour SQLite
        final db = await DBService.database;
        await db.rawUpdate(
          'UPDATE teachers SET role = ?, managed_schools = ?, synced = 1 WHERE id = ?',
          [remoteRole, jsonEncode(remoteManagedSchools), teacher.id],
        );

        return teacher.copyWith(
          role: remoteRole,
          managedSchools: remoteManagedSchools,
        );
      }

      return teacher;
    } catch (e) {
      print('ℹ️ Firestore offline au login: $e');
      return null;
    }
  }

  static Future<void> _syncAfterLogin(Teacher teacher) async {
    try {
      await FirestoreService.upsertTeacher(teacher);
      final report = await SyncEngine.syncAll(teacherId: teacher.id!);
      print('🔄 ${report.message}');
      SyncEngine.startConnectivityWatcher(teacherId: teacher.id!);
    } catch (e) {
      print('ℹ️ Sync différée: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  ÉTAPE 1 INSCRIPTION : Vérifier email avant de créer compte
  // ═══════════════════════════════════════════════════════
  static Future<String?> sendVerificationBeforeRegister({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _fbAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.sendEmailVerification();
      await _fbAuth.signOut();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          try {
            final cred = await _fbAuth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            if (cred.user?.emailVerified == true) {
              await _fbAuth.signOut();
              return 'email_already_verified';
            }
            await cred.user?.sendEmailVerification();
            await _fbAuth.signOut();
            return null;
          } catch (_) {
            return 'Email déjà utilisé avec un autre mot de passe';
          }
        case 'invalid-email':
          return 'Format email invalide';
        case 'weak-password':
          return 'Mot de passe trop faible (min 6 caractères)';
        default:
          return 'Erreur réseau, réessayez';
      }
    } catch (e) {
      return 'Erreur : $e';
    }
  }

  // ═══════════════════════════════════════════════════════
  //  ÉTAPE 2 INSCRIPTION : Compléter après vérification email
  // ═══════════════════════════════════════════════════════
  static Future<RegisterResult> completeRegistrationAfterVerification(
    Teacher teacher,
  ) async {
    try {
      final plainPassword = teacher.passwordHash;
      final passwordHash = SecurityHelper.hashPassword(plainPassword);

      final cred = await _fbAuth.signInWithEmailAndPassword(
        email: teacher.email,
        password: plainPassword,
      );

      if (cred.user == null || !cred.user!.emailVerified) {
        await _fbAuth.signOut();
        return RegisterResult.emailNotVerified;
      }

      final now = DateTime.now().toIso8601String();
      teacher.passwordHash = passwordHash;
      teacher.createdAt = now;
      teacher.updatedAt = now;
      teacher.synced = 0;
      teacher.isActive = 1;
      teacher.deleted = 0;
      teacher.schoolName = teacher.schoolName.trim().toLowerCase();
      teacher.schoolCity = teacher.schoolCity.trim().toLowerCase();

      final success = await DBService.insertTeacher(teacher);
      if (!success) {
        await _fbAuth.signOut();
        return RegisterResult.emailAlreadyUsed;
      }

      final saved = await DBService.login(
        email: teacher.email,
        passwordHash: passwordHash,
      );
      if (saved != null) await _syncNewTeacher(saved);

      await _fbAuth.signOut();
      return RegisterResult.success;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return RegisterResult.error;
      }
      return RegisterResult.error;
    } catch (e) {
      print('🔥 Erreur completeRegistration: $e');
      return RegisterResult.error;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  RENVOYER EMAIL VÉRIFICATION
  // ═══════════════════════════════════════════════════════
  static Future<void> resendVerificationEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _fbAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.sendEmailVerification();
      await _fbAuth.signOut();
    } catch (e) {
      print('❌ Erreur renvoi email: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  LOGOUT
  // ═══════════════════════════════════════════════════════
  static Future<void> logout() async {
    SyncEngine.stopWatcher();
    SessionService.logout();
    try {
      await _fbAuth.signOut();
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  //  PERMISSIONS
  // ═══════════════════════════════════════════════════════
  static bool canViewAllSchool(Teacher u) =>
      u.role == 'admin' || u.role == 'super_admin';
  static bool canViewAllSchools(Teacher u) => u.role == 'super_admin';
  static bool canManageTeachers(Teacher u) =>
      u.role == 'admin' || u.role == 'super_admin';
  static bool canManageRoles(Teacher u) =>
      u.role == 'admin' || u.role == 'super_admin';
  static bool canDeleteObservations(Teacher u) =>
      u.role == 'admin' || u.role == 'super_admin';

  // ✅ NOUVEAU : vérifier si admin peut accéder à une école
  static bool canManageSchool(
    Teacher admin,
    String schoolName,
    String schoolCity,
  ) {
    final name = schoolName.trim().toLowerCase();
    final city = schoolCity.trim().toLowerCase();
    return admin.allManagedSchools.any(
      (s) => s['name'] == name && s['city'] == city,
    );
  }
}

// ═══════════════════════════════════════════════════════
//  Résultats
// ═══════════════════════════════════════════════════════
enum RegisterResult {
  success,
  emailAlreadyUsed,
  weakPassword,
  invalidEmail,
  emailNotVerified,
  error;

  String get message {
    switch (this) {
      case success:
        return '✅ Compte créé avec succès';
      case emailAlreadyUsed:
        return '❌ Email déjà utilisé';
      case weakPassword:
        return '❌ Mot de passe trop faible (6 caractères min)';
      case invalidEmail:
        return '❌ Email invalide';
      case emailNotVerified:
        return '⚠️ Email pas encore confirmé';
      case error:
        return '❌ Une erreur est survenue';
    }
  }
}

class LoginResult {
  final Teacher? teacher;
  final String? error;
  bool get success => teacher != null;
  LoginResult({required this.teacher, this.error});
}
