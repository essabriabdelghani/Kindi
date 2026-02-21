class Teacher {
  int? id;
  String firstName;
  String? lastName;
  String email;
  String? phoneNumber;
  String schoolName;
  String schoolCity;
  String? schoolRegion;
  String role; // teacher, admin, researcher
  String preferredLanguage; // ar, fr, en
  int? yearsOfExperience;
  String? gradeLevel;
  String passwordHash;
  int isActive;
  int synced;
  int deleted;
  String? createdAt;
  String? updatedAt;

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
  });

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
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
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
    );
  }
}
