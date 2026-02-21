// firebase_auth_service.dart — lib/services/firebase_auth_service.dart
//
// Service dédié uniquement à Firebase Authentication.
// Séparé de firestore_service.dart pour garder le code propre.
//
// Utilisé par auth_controller.dart

import 'package:firebase_auth/firebase_auth.dart' as fb;

class FirebaseAuthService {
  static final _auth = fb.FirebaseAuth.instance;

  /// User Firebase actuellement connecté (null si hors-ligne ou non connecté)
  static fb.User? get currentUser => _auth.currentUser;

  static bool get isLoggedIn => _auth.currentUser != null;

  //  CRÉER UN COMPTE

  static Future<FirebaseAuthResult> createAccount({
    required String email,
    required String passwordHash,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: passwordHash,
      );
      print('✅ Firebase Auth : compte créé → ${cred.user?.uid}');
      return FirebaseAuthResult.success(uid: cred.user!.uid);
    } on fb.FirebaseAuthException catch (e) {
      print('❌ Firebase Auth createAccount: ${e.code}');
      return FirebaseAuthResult.fromCode(e.code);
    } catch (e) {
      // Hors-ligne ou autre erreur réseau
      print('ℹ️ Firebase Auth hors ligne (createAccount): $e');
      return FirebaseAuthResult.offline();
    }
  }

  //  CONNEXION

  static Future<FirebaseAuthResult> signIn({
    required String email,
    required String passwordHash,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: passwordHash,
      );
      print('✅ Firebase Auth : connecté → ${cred.user?.uid}');
      return FirebaseAuthResult.success(uid: cred.user!.uid);
    } on fb.FirebaseAuthException catch (e) {
      print('❌ Firebase Auth signIn: ${e.code}');
      return FirebaseAuthResult.fromCode(e.code);
    } catch (e) {
      print('ℹ️ Firebase Auth hors ligne (signIn): $e');
      return FirebaseAuthResult.offline();
    }
  }

  //  DÉCONNEXION
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ Firebase Auth : déconnecté');
    } catch (e) {
      print('ℹ️ Firebase Auth signOut: $e');
    }
  }

  //  RÉINITIALISER MOT DE PASSE (pour plus tard)

  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Email reset envoyé à $email');
      return true;
    } catch (e) {
      print('❌ Reset email: $e');
      return false;
    }
  }
}

//  Résultat d'une opération Firebase Auth

class FirebaseAuthResult {
  final bool ok;
  final String? uid;
  final String? errorCode;
  final bool isOffline;

  const FirebaseAuthResult._({
    required this.ok,
    this.uid,
    this.errorCode,
    this.isOffline = false,
  });

  factory FirebaseAuthResult.success({required String uid}) =>
      FirebaseAuthResult._(ok: true, uid: uid);

  factory FirebaseAuthResult.offline() =>
      FirebaseAuthResult._(ok: false, isOffline: true);

  factory FirebaseAuthResult.fromCode(String code) =>
      FirebaseAuthResult._(ok: false, errorCode: code);

  bool get isEmailAlreadyUsed => errorCode == 'email-already-in-use';
  bool get isWrongPassword =>
      errorCode == 'wrong-password' || errorCode == 'invalid-credential';
  bool get isUserNotFound => errorCode == 'user-not-found';
  bool get isWeakPassword => errorCode == 'weak-password';
  bool get isInvalidEmail => errorCode == 'invalid-email';

  String get message {
    if (ok) return '✅ Succès';
    if (isOffline) return 'ℹ️ Hors ligne — mode local activé';
    switch (errorCode) {
      case 'email-already-in-use':
        return '❌ Email déjà utilisé';
      case 'wrong-password':
      case 'invalid-credential':
        return '❌ Email ou mot de passe incorrect';
      case 'user-not-found':
        return '❌ Aucun compte avec cet email';
      case 'weak-password':
        return '❌ Mot de passe trop faible';
      case 'invalid-email':
        return '❌ Email invalide';
      case 'too-many-requests':
        return '❌ Trop de tentatives, réessayez plus tard';
      case 'network-request-failed':
        return '❌ Pas de connexion internet';
      default:
        return '❌ Erreur: $errorCode';
    }
  }
}
