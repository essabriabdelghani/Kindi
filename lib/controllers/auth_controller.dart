import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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
  //  InscriptionPage envoie le mot de passe EN CLAIR
  //  → on hash UNE SEULE FOIS ici
  // ═══════════════════════════════════════════════════════
  static Future<RegisterResult> register(Teacher teacher) async {
    try {
      // ✅ Garder le mot de passe clair pour Firebase
      final plainPassword = teacher.passwordHash; // clair pour Firebase Auth
      final passwordHash = SecurityHelper.hashPassword(
        plainPassword,
      ); // hash pour SQLite

      // 1️⃣ FIREBASE AUTH — mot de passe EN CLAIR
      try {
        final cred = await _fbAuth.createUserWithEmailAndPassword(
          email: teacher.email,
          password: plainPassword,
        );
        // ✅ Envoyer email de vérification
        await cred.user?.sendEmailVerification();
        print('✅ Firebase Auth : compte créé + email vérification envoyé');
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

      // 2️⃣ SQLITE — stocker le hash (pas le mot de passe clair)
      final now = DateTime.now().toIso8601String();
      teacher.passwordHash = passwordHash; // ← même hash que Firebase
      teacher.createdAt = now;
      teacher.updatedAt = now;
      teacher.synced = 0;
      teacher.isActive = 1;
      teacher.deleted = 0;

      final success = await DBService.insertTeacher(teacher);
      if (!success) return RegisterResult.emailAlreadyUsed;

      // 3️⃣ FIRESTORE
      final saved = await DBService.login(
        email: teacher.email,
        passwordHash: passwordHash,
      );
      if (saved != null) _syncNewTeacher(saved);

      return RegisterResult.success;
    } catch (e) {
      print('🔥 Erreur register: $e');
      return RegisterResult.error;
    }
  }

  static Future<void> _syncNewTeacher(Teacher teacher) async {
    try {
      await FirestoreService.upsertTeacher(teacher);
      final db = await DBService.database;
      await db.update(
        'teachers',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [teacher.id],
      );
    } catch (e) {
      print('ℹ️ Sync différée: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  LOGIN
  //  ConnexionPage envoie DÉJÀ le hash (SecurityHelper.hashPassword)
  //  → NE PAS re-hasher ici
  // ═══════════════════════════════════════════════════════
  static Future<LoginResult> login({
    required String email,
    required String password, // ← mot de passe EN CLAIR pour Firebase
    required String passwordHash, // ← hash SHA-256 pour SQLite
  }) async {
    // 1️⃣ FIREBASE AUTH — mot de passe EN CLAIR
    bool firebaseOk = false;
    try {
      final cred = await _fbAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser != null && !fbUser.emailVerified) {
        // Email pas vérifié → déconnecter et bloquer
        await _fbAuth.signOut();
        return LoginResult(teacher: null, error: 'email_not_verified');
      }
      firebaseOk = true;
      print('✅ Firebase Auth : connecté');
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

    // 2️⃣ SQLITE LOCAL — avec le hash SHA-256
    Teacher? teacher = await DBService.login(
      email: email,
      passwordHash: passwordHash,
    );

    // ✅ CAS RESET PASSWORD :
    // Firebase OK (nouveau mdp en clair) mais SQLite a l'ancien hash
    // → mettre à jour SQLite avec le nouveau hash
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

    // 3️⃣ SESSION + SYNC
    SessionService.login(teacher);
    _syncAfterLogin(teacher);

    return LoginResult(teacher: teacher);
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
      print('✅ Email vérification renvoyé à $email');
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
  //  CHANGER LE RÔLE
  // ═══════════════════════════════════════════════════════
  static Future<bool> changeRole({
    required Teacher currentUser,
    required int targetTeacherId,
    required String newRole,
  }) async {
    final canChange =
        currentUser.role == 'super_admin' ||
        (currentUser.role == 'admin' && newRole != 'super_admin');
    if (!canChange) return false;

    try {
      await DBService.updateTeacher(
        teacherId: targetTeacherId,
        data: {'role': newRole, 'synced': 0},
      );
      await _firestore
          .collection('teachers')
          .doc('teacher_$targetTeacherId')
          .update({
            'role': newRole,
            'updated_at': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      print('❌ changeRole: $e');
      return false;
    }
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
}

// ═══════════════════════════════════════════════════════
//  Résultats
// ═══════════════════════════════════════════════════════
enum RegisterResult {
  success,
  emailAlreadyUsed,
  weakPassword,
  invalidEmail,
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
