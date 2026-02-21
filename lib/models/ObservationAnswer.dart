class ObservationAnswer {
  int? id;
  int observationId;
  int questionId;
  int? numericValue; // 0,1,2
  String? label;
  int synced;
  int deleted;
  String? createdAt;
  String? updatedAt;

  ObservationAnswer({
    this.id,
    required this.observationId,
    required this.questionId,
    this.numericValue,
    this.label,
    this.synced = 1,
    this.deleted = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'observation_id': observationId,
      'question_id': questionId,
      'numeric_value': numericValue,
      'label': label,
      'synced': synced,
      'deleted': deleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ObservationAnswer.fromMap(Map<String, dynamic> map) {
    return ObservationAnswer(
      id: map['id'],
      observationId: map['observation_id'],
      questionId: map['question_id'],
      numericValue: map['numeric_value'],
      label: map['label'],
      synced: map['synced'] ?? 1,
      deleted: map['deleted'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
