// ============================================================
// teachers.dart — lib/models/teachers.dart
// ============================================================

import 'dart:convert';

class Teacher {
  int? id;
  String firstName;
  String? lastName;
  String email;
  String? phoneNumber;
  String schoolName;
  String schoolCity;
  String? schoolRegion;
  String role;
  String preferredLanguage;
  int? yearsOfExperience;
  String? gradeLevel;
  String passwordHash;
  int isActive;
  int synced;
  int deleted;
  String? createdAt;
  String? updatedAt;

  // ✅ NOUVEAU : liste des écoles gérées par l'admin
  // Format : [{'name': 'ecole1', 'city': 'ville1'}, ...]
  // Stocké en JSON dans SQLite, en array dans Firestore
  List<Map<String, String>> managedSchools;

  Teacher({
    this.id,
    required this.firstName,
    this.lastName,
    required this.email,
    this.phoneNumber,
    required this.schoolName,
    required this.schoolCity,
    this.schoolRegion,
    this.role = 'teacher',
    this.preferredLanguage = 'ar',
    this.yearsOfExperience,
    this.gradeLevel,
    required this.passwordHash,
    this.isActive = 1,
    this.synced = 1,
    this.deleted = 0,
    this.createdAt,
    this.updatedAt,
    this.managedSchools = const [],
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';

  // ── Toutes les écoles que cet admin gère ──────────────────
  // Inclut toujours l'école principale + les écoles additionnelles
  List<Map<String, String>> get allManagedSchools {
    final primary = {
      'name': schoolName.trim().toLowerCase(),
      'city': schoolCity.trim().toLowerCase(),
    };
    final extras = managedSchools
        .map(
          (s) => {
            'name': (s['name'] ?? '').trim().toLowerCase(),
            'city': (s['city'] ?? '').trim().toLowerCase(),
          },
        )
        .toList();
    // Dédupliquer
    final all = <Map<String, String>>[primary];
    for (final e in extras) {
      final already = all.any(
        (a) => a['name'] == e['name'] && a['city'] == e['city'],
      );
      if (!already) all.add(e);
    }
    return all;
  }

  // ── school_keys pour requête Firestore ───────────────────
  List<String> get managedSchoolKeys {
    return allManagedSchools.map((s) => '${s['name']}__${s['city']}').toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone_number': phoneNumber,
      'school_name': schoolName,
      'school_city': schoolCity,
      'school_region': schoolRegion,
      'role': role,
      'preferred_language': preferredLanguage,
      'years_of_experience': yearsOfExperience,
      'grade_level': gradeLevel,
      'password_hash': passwordHash,
      'is_active': isActive,
      'synced': synced,
      'deleted': deleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
      // JSON string dans SQLite
      'managed_schools': managedSchools.isNotEmpty
          ? jsonEncode(managedSchools)
          : null,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    List<Map<String, String>> schools = [];
    try {
      final raw = map['managed_schools'];
      if (raw != null && raw.toString().isNotEmpty) {
        final decoded = jsonDecode(raw.toString()) as List;
        schools = decoded
            .map<Map<String, String>>((e) => Map<String, String>.from(e))
            .toList();
      }
    } catch (_) {}

    return Teacher(
      id: map['id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      email: map['email'],
      phoneNumber: map['phone_number'],
      schoolName: map['school_name'],
      schoolCity: map['school_city'],
      schoolRegion: map['school_region'],
      role: map['role'] ?? 'teacher',
      preferredLanguage: map['preferred_language'] ?? 'ar',
      yearsOfExperience: map['years_of_experience'],
      gradeLevel: map['grade_level'],
      passwordHash: map['password_hash'],
      isActive: map['is_active'] ?? 1,
      synced: map['synced'] ?? 1,
      deleted: map['deleted'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      managedSchools: schools,
    );
  }

  Teacher copyWith({
    String? role,
    List<Map<String, String>>? managedSchools,
    String? schoolName,
    String? schoolCity,
  }) {
    return Teacher(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phoneNumber: phoneNumber,
      schoolName: schoolName ?? this.schoolName,
      schoolCity: schoolCity ?? this.schoolCity,
      schoolRegion: schoolRegion,
      role: role ?? this.role,
      preferredLanguage: preferredLanguage,
      yearsOfExperience: yearsOfExperience,
      gradeLevel: gradeLevel,
      passwordHash: passwordHash,
      isActive: isActive,
      synced: synced,
      deleted: deleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      managedSchools: managedSchools ?? this.managedSchools,
    );
  }
}
