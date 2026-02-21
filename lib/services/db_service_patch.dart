// ============================================================
// db_service_patch.dart
//
// PATCH pour db_service.dart existant :
// Chaque INSERT/UPDATE met maintenant synced=0 automatiquement
// pour que SyncEngine sache quoi envoyer à Firebase.
//
// ⚠️ Ce fichier montre SEULEMENT les méthodes à modifier.
//    Remplace les méthodes correspondantes dans ton db_service.dart
// ============================================================

// ───────────────────────────────────────────────────────────
//  PATCH 1 : insertStudent  (ligne ~117 dans db_service.dart)
//  Ajouter 'synced': 0  +  '_owner_school' pour Firebase
// ───────────────────────────────────────────────────────────
/*
static Future<int> insertStudent({
  required String firstName,
  String? lastName,
  required String birthDate,
  required String gender,
  required int classId,
  required int mainTeacherId,
  String? riskLevel,
  required String schoolName,   // ← AJOUTER ce paramètre
  required String schoolCity,   // ← AJOUTER ce paramètre
}) async {
  final db = await database;
  final now = DateTime.now().toIso8601String();

  final id = await db.insert('children', {
    'first_name': firstName,
    'last_name': lastName,
    'gender': gender,
    'birth_date': birthDate,
    'class_id': classId,
    'main_teacher_id': mainTeacherId,
    'latest_overall_risk_level': riskLevel,
    'created_at': now,
    'updated_at': now,
    'synced': 0,  // ← CHANGER de 1 à 0 pour déclencher la sync
  });
  return id;
}
*/

// ───────────────────────────────────────────────────────────
//  PATCH 2 : insertObservationChecklist  (ligne ~185)
//  synced: 0 dans observations ET observation_answers
// ───────────────────────────────────────────────────────────
/*
// Dans la transaction, changer :
  'synced': 1,   →   'synced': 0,
// (dans observation_answers aussi)
*/

// ───────────────────────────────────────────────────────────
//  PATCH 3 : archiveStudent
//  quand on archive → synced=0 pour propager la suppression
// ───────────────────────────────────────────────────────────
/*
static Future<void> archiveStudent(int id) async {
  final db = await database;
  await db.update(
    'children',
    {
      'deleted': 1,
      'synced': 0,  // ← Marquer pour sync (propager deleted=1 à Firebase)
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}
*/

// ───────────────────────────────────────────────────────────
//  PATCH 4 : insertTeacher (dans AuthController.register)
//  Après l'insert SQLite → upsert vers Firestore
// ───────────────────────────────────────────────────────────
/*
// Dans AuthController.register() :
final success = await DBService.insertTeacher(teacher);
if (success) {
  // Récupérer le teacher avec son ID généré
  final saved = await DBService.login(
    email: teacher.email,
    passwordHash: teacher.passwordHash,
  );
  if (saved != null) {
    // Sync immédiate du teacher vers Firestore
    try {
      await FirestoreService.upsertTeacher(saved);
    } catch (_) {
      // Pas grave si hors-ligne, SyncEngine s'en chargera
    }
  }
}
*/
