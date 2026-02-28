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
      if (saved != null) await _syncNewTeacher(saved);

      return RegisterResult.success;
    } catch (e) {
      print('🔥 Erreur register: $e');
      return RegisterResult.error;
    }
  }

  // ═══════════════════════════════════════════════════════
  //  SYNC INSCRIPTION → FIRESTORE
  //  Appelé après chaque inscription réussie
  //  Retry automatique x3 pour garantir que l'admin voit le prof
  // ═══════════════════════════════════════════════════════
  static Future<void> _syncNewTeacher(Teacher teacher) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Envoyer vers Firestore — admin verra le prof en temps réel
        await FirestoreService.upsertTeacher(teacher);

        // Marquer synced=1 dans SQLite
        final db = await DBService.database;
        await db.update(
          'teachers',
          {'synced': 1},
          where: 'id = ?',
          whereArgs: [teacher.id],
        );

        print(
          '✅ Nouveau prof synced vers Firestore (tentative ' +
              attempt.toString() +
              ')',
        );
        return; // succès → sortir
      } catch (e) {
        print(
          '⚠️ Sync tentative ' +
              attempt.toString() +
              '/' +
              maxRetries.toString() +
              ' : ' +
              e.toString(),
        );
        if (attempt < maxRetries) {
          // Attendre avant de réessayer (1s, 2s, 3s)
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    // Après 3 échecs → synced reste 0, SyncEngine l'enverra au prochain lancement
    print('ℹ️ Sync différée — sera envoyée au prochain lancement');
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

    // 3️⃣ SYNC RÔLE DEPUIS FIRESTORE — Firestore fait autorité
    teacher = await _syncRoleFromFirestore(teacher) ?? teacher;

    // 4️⃣ SESSION + SYNC
    SessionService.login(teacher);
    _syncAfterLogin(teacher);

    return LoginResult(teacher: teacher);
  }

  // ── Lire le rôle depuis Firestore au login ──────────────
  // Firestore est la seule source de vérité pour le rôle
  // Un professeur ne peut PAS changer son propre rôle
  static Future<Teacher?> _syncRoleFromFirestore(Teacher teacher) async {
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc('teacher_' + teacher.id.toString())
          .get();

      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final remoteRole = data['role'] as String? ?? 'teacher';

      if (remoteRole != teacher.role) {
        // Mettre à jour SQLite avec le rôle Firestore
        final db = await DBService.database;
        await db.rawUpdate(
          'UPDATE teachers SET role = ?, synced = 1 WHERE id = ?',
          [remoteRole, teacher.id],
        );
        print('✅ Rôle sync depuis Firestore: ' + remoteRole);
        return teacher.copyWith(role: remoteRole);
      }
      return teacher;
    } catch (e) {
      // Offline → garder le rôle SQLite local
      print('ℹ️ Firestore offline au login: ' + e.toString());
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
  //  → Crée un compte Firebase temporaire, envoie verification,
  //    puis supprime le compte Firebase (SQLite pas encore touché)
  // ═══════════════════════════════════════════════════════
  static Future<String?> sendVerificationBeforeRegister({
    required String email,
    required String password,
  }) async {
    try {
      // Créer compte Firebase temporaire
      final cred = await _fbAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Envoyer email de vérification
      await cred.user?.sendEmailVerification();
      // Déconnecter (on garde juste l'email en attente)
      await _fbAuth.signOut();
      print('✅ Email vérification envoyé à $email');
      return null; // null = succès
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          // Vérifier si l'email est déjà vérifié
          try {
            final cred = await _fbAuth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            if (cred.user?.emailVerified == true) {
              await _fbAuth.signOut();
              return 'email_already_verified'; // compte existant vérifié
            }
            // Pas vérifié → renvoyer email
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
  //  → User a cliqué le lien → on finalise SQLite
  // ═══════════════════════════════════════════════════════
  static Future<RegisterResult> completeRegistrationAfterVerification(
    Teacher teacher,
  ) async {
    try {
      final plainPassword = teacher.passwordHash;
      final passwordHash = SecurityHelper.hashPassword(plainPassword);

      // Connecter pour vérifier que l'email est bien vérifié
      final cred = await _fbAuth.signInWithEmailAndPassword(
        email: teacher.email,
        password: plainPassword,
      );

      if (cred.user == null || !cred.user!.emailVerified) {
        await _fbAuth.signOut();
        return RegisterResult.emailNotVerified; // email pas encore confirmé
      }

      // Email vérifié ✅ → sauvegarder dans SQLite
      final now = DateTime.now().toIso8601String();
      teacher.passwordHash = passwordHash;
      teacher.createdAt = now;
      teacher.updatedAt = now;
      teacher.synced = 0;
      teacher.isActive = 1;
      teacher.deleted = 0;

      // Normaliser school avant insert (match admin filter)
      teacher.schoolName = teacher.schoolName.trim().toLowerCase();
      teacher.schoolCity = teacher.schoolCity.trim().toLowerCase();

      final success = await DBService.insertTeacher(teacher);
      if (!success) {
        await _fbAuth.signOut();
        return RegisterResult.emailAlreadyUsed;
      }

      // Sync Firestore immédiat — admin verra le prof en temps réel
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
