import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/teachers.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  //══════════════════════════════════════
  // Ajouter / mettre à jour un professeur
  //══════════════════════════════════════

  static Future<void> upsertTeacher(Teacher t) async {
    final schoolName = t.schoolName.trim().toLowerCase();
    final schoolCity = t.schoolCity.trim().toLowerCase();
    final schoolKey = '${schoolName}__${schoolCity}';

    await _db.collection('teachers').doc('teacher_${t.id}').set({
      'local_id': t.id,
      'first_name': t.firstName,
      'last_name': t.lastName ?? '',
      'email': t.email,
      'phone_number': t.phoneNumber ?? '',
      'school_name': schoolName,
      'school_city': schoolCity,
      'school_key': schoolKey,
      'role': t.role,
      'preferred_language': t.preferredLanguage,
      'years_of_experience': t.yearsOfExperience ?? 0,
      'grade_level': t.gradeLevel ?? '',
      'is_active': t.isActive,
      'deleted': t.deleted,

      'managed_schools': t.managedSchools,
      'managed_school_keys': t.managedSchoolKeys,

      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  //══════════════════════════════════════
  // Ajouter une école gérée
  //══════════════════════════════════════

  static Future<void> addManagedSchool({
    required int adminId,
    required String schoolName,
    required String schoolCity,
  }) async {
    final name = schoolName.trim().toLowerCase();
    final city = schoolCity.trim().toLowerCase();
    final key = '${name}__${city}';

    await _db.collection('teachers').doc('teacher_$adminId').update({
      'managed_schools': FieldValue.arrayUnion([
        {'name': name, 'city': city},
      ]),
      'managed_school_keys': FieldValue.arrayUnion([key]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  //══════════════════════════════════════
  // Supprimer école gérée
  //══════════════════════════════════════

  static Future<void> removeManagedSchool({
    required int adminId,
    required String schoolName,
    required String schoolCity,
  }) async {
    final name = schoolName.trim().toLowerCase();
    final city = schoolCity.trim().toLowerCase();
    final key = '${name}__${city}';

    await _db.collection('teachers').doc('teacher_$adminId').update({
      'managed_schools': FieldValue.arrayRemove([
        {'name': name, 'city': city},
      ]),
      'managed_school_keys': FieldValue.arrayRemove([key]),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  //══════════════════════════════════════
  // Teachers d'une école
  //══════════════════════════════════════

  static Stream<List<Map<String, dynamic>>> streamTeachersInSchool(
    Teacher admin, {
    String? filterSchoolKey,
  }) {
    final schoolKey =
        filterSchoolKey ??
        '${admin.schoolName.toLowerCase()}__${admin.schoolCity.toLowerCase()}';

    return _db
        .collection('teachers')
        .where('school_key', isEqualTo: schoolKey)
        .where('deleted', isEqualTo: 0)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  //══════════════════════════════════════
  // Teachers toutes écoles admin
  //══════════════════════════════════════

  static Stream<List<Map<String, dynamic>>> streamTeachersAllManagedSchools(
    Teacher admin,
  ) {
    final keys = admin.managedSchoolKeys;

    if (keys.isEmpty) {
      return streamTeachersInSchool(admin);
    }

    final limitedKeys = keys.take(10).toList();

    return _db
        .collection('teachers')
        .where('school_key', whereIn: limitedKeys)
        .where('deleted', isEqualTo: 0)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
