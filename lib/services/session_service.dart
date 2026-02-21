import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/teachers.dart';
import 'db_service.dart';
import '../utils/security_helper.dart';

class SessionService {
  // Session en mémoire (rapide)
  static Teacher? currentUser;

  static void login(Teacher user) {
    currentUser = user;
  }

  static void logout() {
    currentUser = null;
  }

  static bool get isLoggedIn => currentUser != null;

  // ✅ NOUVEAU : restaurer la session au démarrage de l'app
  // Firebase Auth garde le token → on récupère le Teacher depuis SQLite
  static Future<Teacher?> restoreSession() async {
    // 1. Vérifier si Firebase Auth a encore une session active
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) return null; // pas de session Firebase → pas connecté

    // 2. Récupérer les données du Teacher depuis SQLite local
    try {
      final db = await DBService.database;
      final result = await db.query(
        'teachers',
        where: 'email = ? AND deleted = 0 AND is_active = 1',
        whereArgs: [fbUser.email],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final teacher = Teacher.fromMap(result.first);
      currentUser = teacher;
      print('✅ Session restaurée : ${teacher.firstName} (${teacher.role})');
      return teacher;
    } catch (e) {
      print('ℹ️ Impossible de restaurer la session: $e');
      return null;
    }
  }
}
