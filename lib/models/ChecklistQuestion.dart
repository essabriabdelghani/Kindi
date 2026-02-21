class ChecklistQuestion {
  int? id;
  String
  domain; // inattention, hyperactivity_impulsivity, self_regulation_social
  int? orderIndex;
  String? textAr;
  String? textFr;
  String? textEn;
  double weight;
  int isActive;
  int synced;
  int deleted;
  String? createdAt;
  String? updatedAt;

  ChecklistQuestion({
    this.id,
    required this.domain,
    this.orderIndex,
    this.textAr,
    this.textFr,
    this.textEn,
    this.weight = 1,
    this.isActive = 1,
    this.synced = 1,
    this.deleted = 0,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'domain': domain,
      'order_index': orderIndex,
      'text_ar': textAr,
      'text_fr': textFr,
      'text_en': textEn,
      'weight': weight,
      'is_active': isActive,
      'synced': synced,
      'deleted': deleted,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory ChecklistQuestion.fromMap(Map<String, dynamic> map) {
    return ChecklistQuestion(
      id: map['id'],
      domain: map['domain'],
      orderIndex: map['order_index'],
      textAr: map['text_ar'],
      textFr: map['text_fr'],
      textEn: map['text_en'],
      weight: map['weight'] ?? 1,
      isActive: map['is_active'] ?? 1,
      synced: map['synced'] ?? 1,
      deleted: map['deleted'] ?? 0,
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
