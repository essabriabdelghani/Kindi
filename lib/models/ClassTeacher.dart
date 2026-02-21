class ClassTeacher {
  int? id; // identifiant unique de la relation
  int classId; // identifiant de la classe
  int teacherId; // identifiant de l'enseignant
  String role; // 'main' ou 'co'

  ClassTeacher({
    this.id,
    required this.classId,
    required this.teacherId,
    this.role = 'co',
  });

  // Convertir en map pour la base de données
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'class_id': classId,
      'teacher_id': teacherId,
      'role': role,
    };
  }

  // Créer un objet depuis une map (ex: DB)
  factory ClassTeacher.fromMap(Map<String, dynamic> map) {
    return ClassTeacher(
      id: map['id'],
      classId: map['class_id'],
      teacherId: map['teacher_id'],
      role: map['role'] ?? 'co',
    );
  }
}
