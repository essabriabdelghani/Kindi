class Observation {
  int? id;
  int childId;
  int teacherId;
  int classId;
  String? date;
  String? context;
  String? notes;
  double? inattentionRawScore;
  double? hyperactivityRawScore;
  double? selfregSocialRawScore;
  double? totalRawScore;
  double? inattentionPercent;
  double? hyperactivityPercent;
  double? selfregSocialPercent;
  double? totalPercent;
  String? overallRiskLevel; // green, orange, red
  int synced;
  int deleted;
  String? createdAt;
  String? updatedAt;

  Observation({
    this.id,
    required this.childId,
    required this.teacherId,
    required this.classId,
    this.date,
    this.context,
    this.notes,
    this.inattentionRawScore,
    this.hyperactivityRawScore,
    this.selfregSocialRawScore,
    this.totalRawScore,
    this.inattentionPercent,
    this.hyperactivityPercent,
    this.selfregSocialPercent,
    this.totalPercent,
    this.overallRiskLevel,
    this.synced = 1,
    this.deleted = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'child_id': childId,
      'teacher_id': teacherId,
      'class_id': classId,
      'date': date,
      'context': context,
      'notes': notes,
      'inattention_raw_score': inattentionRawScore,
      'hyperactivity_raw_score': hyperactivityRawScore,
      'selfreg_social_raw_score': selfregSocialRawScore,
      'total_raw_score': totalRawScore,
      'inattention_percent': inattentionPercent,
      'hyperactivity_percent': hyperactivityPercent,
      'selfreg_social_percent': selfregSocialPercent,
      'total_percent': totalPercent,
      'overall_risk_level': overallRiskLevel,
      'synced': synced,
      'deleted': deleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Observation.fromMap(Map<String, dynamic> map) {
    return Observation(
      id: map['id'],
      childId: map['child_id'],
      teacherId: map['teacher_id'],
      classId: map['class_id'],
      date: map['date'],
      context: map['context'],
      notes: map['notes'],
      inattentionRawScore: map['inattention_raw_score'],
      hyperactivityRawScore: map['hyperactivity_raw_score'],
      selfregSocialRawScore: map['selfreg_social_raw_score'],
      totalRawScore: map['total_raw_score'],
      inattentionPercent: map['inattention_percent'],
      hyperactivityPercent: map['hyperactivity_percent'],
      selfregSocialPercent: map['selfreg_social_percent'],
      totalPercent: map['total_percent'],
      overallRiskLevel: map['overall_risk_level'],
      synced: map['synced'] ?? 1,
      deleted: map['deleted'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
