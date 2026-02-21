class Child {
  int? id;
  String? childCode;
  String firstName;
  String? lastName;
  String gender; // boy, girl
  String? birthDate;
  int classId;
  int mainTeacherId;
  String? latestOverallRiskLevel; // green, orange, red
  String? latestObservationDate;
  String? notes;
  int synced;
  int deleted;
  String? createdAt;
  String? updatedAt;

  Child({
    this.id,
    this.childCode,
    required this.firstName,
    this.lastName,
    this.gender = 'boy',
    this.birthDate,
    required this.classId,
    required this.mainTeacherId,
    this.latestOverallRiskLevel,
    this.latestObservationDate,
    this.notes,
    this.synced = 1,
    this.deleted = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_code': childCode,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'birth_date': birthDate,
      'class_id': classId,
      'main_teacher_id': mainTeacherId,
      'latest_overall_risk_level': latestOverallRiskLevel,
      'latest_observation_date': latestObservationDate,
      'notes': notes,
      'synced': synced,
      'deleted': deleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Child.fromMap(Map<String, dynamic> map) {
    return Child(
      id: map['id'],
      childCode: map['child_code'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      gender: map['gender'] ?? 'boy',
      birthDate: map['birth_date'],
      classId: map['class_id'],
      mainTeacherId: map['main_teacher_id'],
      latestOverallRiskLevel: map['latest_overall_risk_level'],
      latestObservationDate: map['latest_observation_date'],
      notes: map['notes'],
      synced: map['synced'] ?? 1,
      deleted: map['deleted'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
