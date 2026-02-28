// ============================================================
// firestore_service.dart — lib/services/firestore_service.dart
//
// Gère la logique de rôles dans Firestore :
//
//  👤 teacher      → voit SES classes, SES élèves, SES observations
//  🔑 admin        → voit TOUTE son école (même école, même ville)
//  👑 super_admin  → voit TOUT (toutes les écoles, toutes les villes)
//
// Les données sont filtrées par school_name + school_city pour
// isoler les écoles entre elles.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teachers.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════
  //  TEACHERS / USERS
  // ═══════════════════════════════════════════════════════

  /// Créer ou mettre à jour le profil d'un teacher dans Firestore
  /// Appelé à l'inscription ET après chaque mise à jour de profil
  static Future<void> upsertTeacher(Teacher t) async {
    // Normaliser school pour garantir le matching admin ↔ prof
    final schoolName = t.schoolName.trim().toLowerCase();
    final schoolCity = t.schoolCity.trim().toLowerCase();
    final schoolKey = schoolName + '__' + schoolCity; // index composite

    await _db.collection('teachers').doc('teacher_' + t.id.toString()).set({
      'local_id': t.id,
      'first_name': t.firstName,
      'last_name': t.lastName ?? '',
      'email': t.email,
      'phone_number': t.phoneNumber ?? '',
      'school_name': schoolName, // ✅ toujours lowercase
      'school_city': schoolCity, // ✅ toujours lowercase
      'school_key': schoolKey, // ✅ index composite pour requête fiable
      'school_region': t.schoolRegion ?? '',
      'role': t.role,
      'preferred_language': t.preferredLanguage,
      'years_of_experience': t.yearsOfExperience ?? 0,
      'grade_level': t.gradeLevel ?? '',
      'is_active': t.isActive,
      'deleted': t.deleted,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────
  //  LECTURE SELON RÔLE
  // ─────────────────────────────────────────────────────────

  /// Teachers de la même école (pour Admin)
  static Stream<List<Map<String, dynamic>>> streamTeachersInSchool(
    Teacher admin,
  ) {
    // Utiliser school_key normalisé pour éviter les problèmes de casse
    final schoolKey =
        admin.schoolName.trim().toLowerCase() +
        '__' +
        admin.schoolCity.trim().toLowerCase();

    return _db
        .collection('teachers')
        .where('school_key', isEqualTo: schoolKey)
        .where('deleted', isEqualTo: 0)
        .snapshots()
        .map(_docsToList);
  }

  /// Toutes les écoles (pour Super Admin)
  static Stream<List<Map<String, dynamic>>> streamAllTeachers() {
    return _db
        .collection('teachers')
        .where('deleted', isEqualTo: 0)
        .orderBy('school_name')
        .snapshots()
        .map(_docsToList);
  }

  // ═══════════════════════════════════════════════════════
  //  CHILDREN — selon rôle
  // ═══════════════════════════════════════════════════════

  /// Enfants du professeur connecté (Teacher)
  static Stream<List<Map<String, dynamic>>> streamMyChildren(Teacher t) {
    return _db
        .collection('children')
        .where('main_teacher_id', isEqualTo: t.id)
        .where('deleted', isEqualTo: 0)
        .orderBy('first_name')
        .snapshots()
        .map(_docsToList);
  }

  /// Tous les enfants de l'école (Admin)
  static Stream<List<Map<String, dynamic>>> streamSchoolChildren(
    Teacher admin,
  ) {
    return _db
        .collection('children')
        .where(
          '_owner_school',
          isEqualTo: '${admin.schoolName}__${admin.schoolCity}',
        )
        .where('deleted', isEqualTo: 0)
        .orderBy('first_name')
        .snapshots()
        .map(_docsToList);
  }

  /// Tous les enfants de partout (Super Admin)
  static Stream<List<Map<String, dynamic>>> streamAllChildren() {
    return _db
        .collection('children')
        .where('deleted', isEqualTo: 0)
        .orderBy('first_name')
        .snapshots()
        .map(_docsToList);
  }

  // ═══════════════════════════════════════════════════════
  //  OBSERVATIONS — selon rôle
  // ═══════════════════════════════════════════════════════

  /// Observations faites par ce teacher
  static Stream<List<Map<String, dynamic>>> streamMyObservations(Teacher t) {
    return _db
        .collection('observations')
        .where('teacher_id', isEqualTo: t.id)
        .where('deleted', isEqualTo: 0)
        .orderBy('date', descending: true)
        .snapshots()
        .map(_docsToList);
  }

  /// Observations d'un enfant spécifique (toujours visible par son teacher)
  static Stream<List<Map<String, dynamic>>> streamChildObservations(
    int childId,
  ) {
    return _db
        .collection('observations')
        .where('child_id', isEqualTo: childId)
        .where('deleted', isEqualTo: 0)
        .orderBy('date', descending: true)
        .snapshots()
        .map(_docsToList);
  }

  /// Toutes les observations de l'école (Admin)
  static Stream<List<Map<String, dynamic>>> streamSchoolObservations(
    Teacher admin,
  ) {
    return _db
        .collection('observations')
        .where(
          '_owner_school',
          isEqualTo: '${admin.schoolName}__${admin.schoolCity}',
        )
        .where('deleted', isEqualTo: 0)
        .orderBy('date', descending: true)
        .snapshots()
        .map(_docsToList);
  }

  // ═══════════════════════════════════════════════════════
  //  STATS — tableaux de bord
  // ═══════════════════════════════════════════════════════

  /// Stats risques pour le teacher (son tableau de bord)
  static Future<Map<String, int>> riskStatsForTeacher(Teacher t) async {
    final snap = await _db
        .collection('children')
        .where('main_teacher_id', isEqualTo: t.id)
        .where('deleted', isEqualTo: 0)
        .get();

    return _computeRiskStats(snap.docs);
  }

  /// Stats risques pour toute l'école (Admin)
  static Future<Map<String, int>> riskStatsForSchool(Teacher admin) async {
    final snap = await _db
        .collection('children')
        .where(
          '_owner_school',
          isEqualTo: '${admin.schoolName}__${admin.schoolCity}',
        )
        .where('deleted', isEqualTo: 0)
        .get();

    return _computeRiskStats(snap.docs);
  }

  /// Stats globales toutes écoles (Super Admin)
  static Future<Map<String, int>> riskStatsGlobal() async {
    final snap = await _db
        .collection('children')
        .where('deleted', isEqualTo: 0)
        .get();

    return _computeRiskStats(snap.docs);
  }

  // ─────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _docsToList(QuerySnapshot snap) {
    return snap.docs
        .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
        .toList();
  }

  static Map<String, int> _computeRiskStats(List<QueryDocumentSnapshot> docs) {
    final stats = {'green': 0, 'orange': 0, 'red': 0, 'unknown': 0};
    for (final doc in docs) {
      final risk = (doc.data() as Map)['latest_overall_risk_level'] as String?;
      if (risk != null && stats.containsKey(risk)) {
        stats[risk] = (stats[risk] ?? 0) + 1;
      } else {
        stats['unknown'] = (stats['unknown'] ?? 0) + 1;
      }
    }
    return stats;
  }
}
