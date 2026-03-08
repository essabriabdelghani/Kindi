// ============================================================
// db_service.dart — lib/services/db_service.dart
// v3 : ajout managed_schools dans teachers + queries multi-écoles
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/teachers.dart';

class DBService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'kindi.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      try {
        await db.execute('ALTER TABLE teachers RENAME TO teachers_old');
        await db.execute(_teachersCreateSQL());
        await db.execute('''
          INSERT INTO teachers SELECT
            id, first_name, last_name, email, phone_number,
            school_name, school_city, school_region, role,
            preferred_language, years_of_experience, grade_level,
            password_hash, is_active, synced, deleted, created_at, updated_at,
            NULL
          FROM teachers_old
        ''');
        await db.execute('DROP TABLE teachers_old');
        print('✅ Migration v2 : contrainte role supprimée');
      } catch (e) {
        print('⚠️ Migration v2 error: $e');
      }
    }
    if (oldV < 3) {
      // ✅ Migration v3 : ajouter colonne managed_schools
      try {
        await db.execute(
          'ALTER TABLE teachers ADD COLUMN managed_schools TEXT',
        );
        print('✅ Migration v3 : colonne managed_schools ajoutée');
      } catch (e) {
        print('ℹ️ Migration v3 (déjà présente ?): $e');
      }
    }
  }

  static String _teachersCreateSQL() => '''
    CREATE TABLE teachers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      first_name TEXT NOT NULL,
      last_name TEXT,
      email TEXT UNIQUE NOT NULL,
      phone_number TEXT,
      school_name TEXT NOT NULL,
      school_city TEXT NOT NULL,
      school_region TEXT,
      role TEXT NOT NULL DEFAULT 'teacher',
      preferred_language TEXT,
      years_of_experience INTEGER,
      grade_level TEXT,
      password_hash TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      synced INTEGER DEFAULT 1,
      deleted INTEGER DEFAULT 0,
      created_at TEXT,
      updated_at TEXT,
      managed_schools TEXT
    )
  ''';

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(_teachersCreateSQL());

    await db.execute('''
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        level TEXT,
        school_name TEXT,
        school_city TEXT,
        academic_year TEXT,
        shift TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE class_teachers (
        id INTEGER PRIMARY KEY,
        class_id INTEGER NOT NULL,
        teacher_id INTEGER NOT NULL,
        role TEXT,
        FOREIGN KEY(class_id) REFERENCES classes(id),
        FOREIGN KEY(teacher_id) REFERENCES teachers(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE children (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        child_code TEXT UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT,
        gender TEXT,
        birth_date TEXT,
        class_id INTEGER NOT NULL,
        main_teacher_id INTEGER NOT NULL,
        latest_overall_risk_level TEXT,
        latest_observation_date TEXT,
        notes TEXT,
        synced INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (class_id) REFERENCES classes(id),
        FOREIGN KEY (main_teacher_id) REFERENCES teachers(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE checklist_questions (
        id INTEGER PRIMARY KEY,
        domain TEXT,
        order_index INTEGER,
        text_ar TEXT,
        text_fr TEXT,
        text_en TEXT,
        weight REAL DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE observations (
        id INTEGER PRIMARY KEY,
        child_id INTEGER NOT NULL,
        teacher_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        date TEXT,
        context TEXT,
        notes TEXT,
        inattention_raw_score REAL,
        hyperactivity_raw_score REAL,
        selfreg_social_raw_score REAL,
        total_raw_score REAL,
        inattention_percent REAL,
        hyperactivity_percent REAL,
        selfreg_social_percent REAL,
        total_percent REAL,
        overall_risk_level TEXT,
        synced INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (child_id) REFERENCES children(id),
        FOREIGN KEY (teacher_id) REFERENCES teachers(id),
        FOREIGN KEY (class_id) REFERENCES classes(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE observation_answers (
        id INTEGER PRIMARY KEY,
        observation_id INTEGER NOT NULL,
        question_id INTEGER NOT NULL,
        numeric_value INTEGER,
        label TEXT,
        synced INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (observation_id) REFERENCES observations(id),
        FOREIGN KEY (question_id) REFERENCES checklist_questions(id)
      );
    ''');

    await db.execute('CREATE INDEX idx_children_class ON children(class_id);');
    await db.execute(
      'CREATE INDEX idx_observations_child ON observations(child_id);',
    );
    await db.execute(
      'CREATE INDEX idx_observations_class ON observations(class_id);',
    );
    await db.execute(
      'CREATE INDEX idx_observation_answers_obs ON observation_answers(observation_id);',
    );
    await db.execute(
      'CREATE INDEX idx_class_teachers_class ON class_teachers(class_id);',
    );
  }

  // ===== INSERT TEACHER =====
  static Future<bool> insertTeacher(Teacher teacher) async {
    final db = await database;
    try {
      await db.insert(
        'teachers',
        teacher.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===== LOGIN =====
  static Future<Teacher?> login({
    required String email,
    required String passwordHash,
  }) async {
    final db = await database;
    final result = await db.query(
      'teachers',
      where:
          'email = ? AND password_hash = ? AND is_active = 1 AND deleted = 0',
      whereArgs: [email, passwordHash],
      limit: 1,
    );
    if (result.isNotEmpty) return Teacher.fromMap(result.first);
    return null;
  }

  static Future<Teacher?> getTeacherByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      'teachers',
      where: 'email = ? AND is_active = 1 AND deleted = 0',
      whereArgs: [email],
      limit: 1,
    );
    if (result.isNotEmpty) return Teacher.fromMap(result.first);
    return null;
  }

  static Future<void> updatePasswordHash({
    required String email,
    required String newPasswordHash,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {
        'password_hash': newPasswordHash,
        'synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'email = ? AND deleted = 0',
      whereArgs: [email],
    );
  }

  // ===== UPDATE MANAGED SCHOOLS (SQLite) =====
  static Future<void> updateManagedSchools({
    required int adminId,
    required List<Map<String, String>> schools,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {
        'managed_schools': jsonEncode(schools),
        'synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [adminId],
    );
  }

  // ===== GET CLASSES =====
  static Future<List<Map<String, dynamic>>> getClassesByTeacher(
    int teacherId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.* FROM classes c
      INNER JOIN class_teachers ct ON ct.class_id = c.id
      WHERE ct.teacher_id = ? AND c.deleted = 0
      ORDER BY c.name ASC
    ''',
      [teacherId],
    );
  }

  static Future<List<Map<String, dynamic>>> getStudentsByClass(
    int classId,
  ) async {
    final db = await database;
    return await db.query(
      'children',
      where: 'class_id = ? AND deleted = 0',
      whereArgs: [classId],
      orderBy: 'first_name ASC',
    );
  }

  // ===== INSERT STUDENT =====
  static Future<void> insertStudent({
    required String firstName,
    String? lastName,
    required String birthDate,
    required String gender,
    required int classId,
    required int mainTeacherId,
    String? riskLevel,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('children', {
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'birth_date': birthDate,
      'class_id': classId,
      'main_teacher_id': mainTeacherId,
      'latest_overall_risk_level': riskLevel,
      'synced': 0,
      'deleted': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<void> archiveStudent(int id) async {
    final db = await database;
    await db.update(
      'children',
      {
        'deleted': 1,
        'synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteStudent(int id) async {
    final db = await database;
    final rows = await db.query(
      'children',
      columns: ['id', 'child_code'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.delete('children', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final childCode = rows.first['child_code']?.toString();
      final docId = childCode ?? 'child_$id';
      try {
        await FirebaseFirestore.instance
            .collection('children')
            .doc(docId)
            .delete();
      } catch (e) {}
    }
  }

  static Future<List<Map<String, dynamic>>> getArchivedStudentsByClass(
    int classId,
  ) async {
    final db = await database;
    return await db.query(
      'children',
      where: 'class_id = ? AND deleted = 1',
      whereArgs: [classId],
      orderBy: 'first_name ASC',
    );
  }

  static Future<void> unarchiveStudent(int id) async {
    final db = await database;
    await db.update(
      'children',
      {'deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<Map<String, dynamic>?> getStudentById(int id) async {
    final db = await database;
    final res = await db.query(
      'children',
      where: 'id = ? AND deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<List<Map<String, dynamic>>> getObservationsByStudent(
    int studentId,
  ) async {
    final db = await database;
    return await db.query(
      'observations',
      where: 'child_id = ? AND deleted = 0',
      whereArgs: [studentId],
      orderBy: 'date DESC, created_at DESC',
    );
  }

  static Future<void> insertObservation({
    required int childId,
    required int teacherId,
    required int classId,
    required String context,
    required String notes,
    required String overallRiskLevel,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('observations', {
      'child_id': childId,
      'teacher_id': teacherId,
      'class_id': classId,
      'date': now,
      'context': context,
      'notes': notes,
      'overall_risk_level': overallRiskLevel,
      'created_at': now,
      'updated_at': now,
      'deleted': 0,
      'synced': 1,
    });
    await db.update(
      'children',
      {
        'latest_overall_risk_level': overallRiskLevel,
        'latest_observation_date': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [childId],
    );
  }

  static String computeRiskLevel(double percent) {
    if (percent >= 70) return "red";
    if (percent >= 40) return "orange";
    return "green";
  }

  static Future<void> insertObservationChecklist({
    required int childId,
    required int teacherId,
    required int classId,
    required String context,
    required String notes,
    required Map<int, int> answers,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final totalScore = answers.values.fold<int>(0, (a, b) => a + b);
    final maxScore = answers.length * 2;
    final percent = (totalScore / maxScore) * 100;
    final risk = computeRiskLevel(percent);
    double inattention = 0, hyper = 0, selfreg = 0;
    final qs = await db.query(
      "checklist_questions",
      columns: ["id", "domain"],
      where: "id IN (${answers.keys.map((_) => '?').join(',')})",
      whereArgs: answers.keys.toList(),
    );
    for (final q in qs) {
      final id = q["id"] as int;
      final domain = q["domain"] as String?;
      final val = answers[id] ?? 0;
      if (domain == "inattention") inattention += val;
      if (domain == "hyperactivity_impulsivity") hyper += val;
      if (domain == "self_regulation_social") selfreg += val;
    }
    await db.transaction((txn) async {
      final obsId = await txn.insert("observations", {
        "child_id": childId,
        "teacher_id": teacherId,
        "class_id": classId,
        "date": now,
        "context": context,
        "notes": notes,
        "inattention_raw_score": inattention,
        "hyperactivity_raw_score": hyper,
        "selfreg_social_raw_score": selfreg,
        "total_raw_score": totalScore.toDouble(),
        "total_percent": percent,
        "overall_risk_level": risk,
        "created_at": now,
        "updated_at": now,
        "deleted": 0,
        "synced": 0,
      });
      for (final entry in answers.entries) {
        await txn.insert("observation_answers", {
          "observation_id": obsId,
          "question_id": entry.key,
          "numeric_value": entry.value,
          "created_at": now,
          "updated_at": now,
          "deleted": 0,
          "synced": 0,
        });
      }
      await txn.update(
        "children",
        {
          "latest_overall_risk_level": risk,
          "latest_observation_date": now,
          "updated_at": now,
        },
        where: "id = ?",
        whereArgs: [childId],
      );
    });
  }

  static Future<List<Map<String, dynamic>>> getChecklistQuestions() async {
    final db = await database;
    return await db.query(
      'checklist_questions',
      where: 'is_active = 1 AND deleted = 0',
      orderBy: 'order_index ASC',
    );
  }

  static Future<void> insertChecklistQuestions() async {
    final db = await database;
    final exist = await checklistQuestionsExist();
    if (exist) return;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> questions = [
      {
        "domain": "inattention",
        "order_index": 1,
        "text_en": "Has difficulty staying focused during activities.",
        "text_fr": "A du mal à rester concentré pendant les activités.",
        "text_ar": "يواجه صعوبة في التركيز أثناء الأنشطة.",
      },
      {
        "domain": "inattention",
        "order_index": 2,
        "text_en": "Gets easily distracted by noises or movements.",
        "text_fr":
            "Se laisse facilement distraire par les bruits ou les mouvements.",
        "text_ar": "يتشتت بسهولة بسبب الأصوات أو الحركات.",
      },
      {
        "domain": "inattention",
        "order_index": 3,
        "text_en": "Has trouble finishing tasks or activities.",
        "text_fr": "A du mal à terminer les tâches ou les activités.",
        "text_ar": "يجد صعوبة في إنهاء المهام أو الأنشطة.",
      },
      {
        "domain": "inattention",
        "order_index": 4,
        "text_en": "Forgets instructions easily.",
        "text_fr": "Oublie facilement les consignes.",
        "text_ar": "ينسى التعليمات بسهولة.",
      },
      {
        "domain": "inattention",
        "order_index": 5,
        "text_en": "Has difficulty following multi-step instructions.",
        "text_fr":
            "A du mal à suivre les consignes comportant plusieurs étapes.",
        "text_ar": "يواجه صعوبة في اتباع التعليمات متعددة الخطوات.",
      },
      {
        "domain": "inattention",
        "order_index": 6,
        "text_en": "Avoids or dislikes tasks that require sustained attention.",
        "text_fr":
            "Évite ou n'aime pas les tâches nécessitant une attention soutenue.",
        "text_ar": "يتجنب أو لا يحب المهام التي تتطلب تركيزاً مستمراً.",
      },
      {
        "domain": "inattention",
        "order_index": 7,
        "text_en": "Makes careless mistakes in simple tasks.",
        "text_fr": "Fait des erreurs d'inattention dans des tâches simples.",
        "text_ar": "يرتكب أخطاء غير متعمدة في المهام البسيطة.",
      },
      {
        "domain": "inattention",
        "order_index": 8,
        "text_en": "Has difficulty organizing tasks or materials.",
        "text_fr": "A des difficultés à organiser ses tâches ou son matériel.",
        "text_ar": "يجد صعوبة في تنظيم المهام أو المواد.",
      },
      {
        "domain": "inattention",
        "order_index": 9,
        "text_en": "Frequently loses objects needed for activities.",
        "text_fr": "Perd souvent les objets nécessaires aux activités.",
        "text_ar": "يفقد كثيراً الأشياء اللازمة للأنشطة.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 10,
        "text_en": "Has difficulty remaining seated during group activities.",
        "text_fr": "A du mal à rester assis pendant les activités de groupe.",
        "text_ar": "يجد صعوبة في البقاء جالساً أثناء الأنشطة الجماعية.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 11,
        "text_en":
            "Moves excessively: runs, climbs, or jumps at inappropriate times.",
        "text_fr":
            "Bouge excessivement : court, grimpe ou saute à des moments inappropriés.",
        "text_ar":
            "يتحرك بشكل مفرط: يركض أو يتسلق أو يقفز في أوقات غير مناسبة.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 12,
        "text_en": "Fidgets constantly (hands, feet, or body).",
        "text_fr": "S'agite constamment (mains, pieds ou corps).",
        "text_ar": "يتململ باستمرار (اليدين، القدمين أو الجسم).",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 13,
        "text_en": "Talks excessively during activities.",
        "text_fr": "Parle excessivement pendant les activités.",
        "text_ar": "يتحدث كثيراً أثناء الأنشطة.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 14,
        "text_en": "Interrupts classmates or adults frequently.",
        "text_fr": "Interrompt fréquemment les camarades ou les adultes.",
        "text_ar": "يقاطع زملاءه أو الكبار بشكل متكرر.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 15,
        "text_en": "Has difficulty waiting for their turn.",
        "text_fr": "A du mal à attendre son tour.",
        "text_ar": "يجد صعوبة في الانتظار لدوره.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 16,
        "text_en": "Acts without thinking about consequences.",
        "text_fr": "Agit sans réfléchir aux conséquences.",
        "text_ar": "يتصرف دون التفكير في العواقب.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 17,
        "text_en": "Gives quick answers before questions are finished.",
        "text_fr": "Répond trop vite avant la fin de la question.",
        "text_ar": "يجيب بسرعة قبل انتهاء السؤال.",
      },
      {
        "domain": "hyperactivity_impulsivity",
        "order_index": 18,
        "text_en": "Leaves seat or work area when not supposed to.",
        "text_fr": "Quitte sa place ou son espace de travail sans permission.",
        "text_ar": "يترك مكانه أو مساحة عمله بدون إذن.",
      },
      {
        "domain": "self_regulation_social",
        "order_index": 19,
        "text_en":
            "Has difficulty managing emotions (frustration, anger, sadness).",
        "text_fr":
            "A du mal à gérer ses émotions (frustration, colère, tristesse).",
        "text_ar": "يواجه صعوبة في التحكم بمشاعره (الإحباط، الغضب، الحزن).",
      },
      {
        "domain": "self_regulation_social",
        "order_index": 20,
        "text_en": "Becomes upset quickly when routines change.",
        "text_fr": "Se fâche rapidement lorsque les routines changent.",
        "text_ar": "يغضب بسرعة عند تغيير الروتين اليومي.",
      },
      {
        "domain": "self_regulation_social",
        "order_index": 21,
        "text_en": "Struggles to calm down after excitement or conflict.",
        "text_fr": "A du mal à se calmer après une excitation ou un conflit.",
        "text_ar": "يجد صعوبة في الهدوء بعد الانفعال أو النزاع.",
      },
      {
        "domain": "self_regulation_social",
        "order_index": 22,
        "text_en": "Has difficulty sharing or playing cooperatively.",
        "text_fr": "A du mal à partager ou à jouer de manière coopérative.",
        "text_ar": "يواجه صعوبة في المشاركة أو اللعب بطريقة تعاونية.",
      },
      {
        "domain": "self_regulation_social",
        "order_index": 23,
        "text_en": "Shows impulsive physical behaviors (grabbing, pushing).",
        "text_fr":
            "Montre des comportements physiques impulsifs (attraper, pousser).",
        "text_ar": "يظهر سلوكيات جسدية متهورة (كالشد أو الدفع).",
      },
      {
        "domain": "self_regulation_social",
        "order_index": 24,
        "text_en": "Needs frequent reminders to follow rules or routines.",
        "text_fr":
            "A besoin de rappels fréquents pour suivre les règles ou les routines.",
        "text_ar": "يحتاج إلى تذكيرات متكررة لاتباع القواعد أو الروتين.",
      },
    ];
    await db.transaction((txn) async {
      for (final q in questions) {
        await txn.insert("checklist_questions", {
          ...q,
          "weight": 1,
          "is_active": 1,
          "synced": 1,
          "deleted": 0,
          "created_at": now,
          "updated_at": now,
        });
      }
    });
  }

  static Future<bool> checklistQuestionsExist() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as c FROM checklist_questions WHERE deleted = 0",
    );
    return (Sqflite.firstIntValue(res) ?? 0) > 0;
  }

  static Future<List<Map<String, dynamic>>> getActiveStudentsByTeacher(
    int teacherId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT ch.*, c.name AS class_name FROM children ch
      LEFT JOIN classes c ON c.id = ch.class_id
      WHERE ch.main_teacher_id = ? AND ch.deleted = 0
      ORDER BY ch.first_name ASC
    ''',
      [teacherId],
    );
  }

  static Future<List<Map<String, dynamic>>> getDashboardStats(
    int teacherId,
  ) async {
    final db = await database;
    final classes = await db.rawQuery(
      '''
      SELECT c.id, c.name, c.level, c.academic_year FROM classes c
      INNER JOIN class_teachers ct ON ct.class_id = c.id
      WHERE ct.teacher_id = ? AND c.deleted = 0 ORDER BY c.name ASC
    ''',
      [teacherId],
    );
    final List<Map<String, dynamic>> result = [];
    for (final cls in classes) {
      final classId = cls['id'] as int;
      final countRes = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM children WHERE class_id = ? AND deleted = 0',
        [classId],
      );
      final total = (countRes.first['total'] as int?) ?? 0;
      final riskRes = await db.rawQuery(
        'SELECT latest_overall_risk_level AS risk, COUNT(*) AS cnt FROM children WHERE class_id = ? AND deleted = 0 GROUP BY latest_overall_risk_level',
        [classId],
      );
      int green = 0, orange = 0, red = 0;
      for (final r in riskRes) {
        if (r['risk'] == 'green') green = (r['cnt'] as int?) ?? 0;
        if (r['risk'] == 'orange') orange = (r['cnt'] as int?) ?? 0;
        if (r['risk'] == 'red') red = (r['cnt'] as int?) ?? 0;
      }
      final recentStudents = await db.rawQuery(
        'SELECT first_name, last_name, latest_overall_risk_level, gender FROM children WHERE class_id = ? AND deleted = 0 ORDER BY created_at DESC LIMIT 3',
        [classId],
      );
      result.add({
        'id': classId,
        'name': cls['name'],
        'level': cls['level'] ?? '',
        'academic_year': cls['academic_year'] ?? '',
        'total': total,
        'green': green,
        'orange': orange,
        'red': red,
        'recent': recentStudents,
      });
    }
    return result;
  }

  static Future<Map<String, int>> getRiskStatsByTeacher(int teacherId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT latest_overall_risk_level AS risk, COUNT(*) AS count FROM children WHERE main_teacher_id = ? AND deleted = 0 GROUP BY latest_overall_risk_level',
      [teacherId],
    );
    final Map<String, int> stats = {'green': 0, 'orange': 0, 'red': 0};
    for (final row in result) {
      final risk = row['risk'] as String?;
      final count = row['count'] as int?;
      if (risk != null && count != null) stats[risk] = count;
    }
    return stats;
  }

  // ═══════════════════════════════════════════════════════
  // MULTI-ÉCOLE : queries pour admin gérant plusieurs écoles
  // ═══════════════════════════════════════════════════════

  /// Tous les élèves de TOUTES les écoles gérées par l'admin
  static Future<List<Map<String, dynamic>>> getAllChildrenForAdmin({
    required Teacher admin,
    String? filterSchoolName, // null = toutes les écoles
    String? filterSchoolCity,
  }) async {
    final db = await database;
    final schools = admin.allManagedSchools;

    if (schools.isEmpty) return [];

    // Filtre sur une école spécifique
    if (filterSchoolName != null && filterSchoolCity != null) {
      return await getAllChildrenWithDetails(
        schoolName: filterSchoolName,
        schoolCity: filterSchoolCity,
      );
    }

    // Toutes les écoles → union des résultats
    final List<Map<String, dynamic>> all = [];
    for (final school in schools) {
      final kids = await getAllChildrenWithDetails(
        schoolName: school['name']!,
        schoolCity: school['city']!,
      );
      // Ajouter le nom de l'école pour distinguer
      for (final k in kids) {
        all.add({
          ...k,
          '_school_name': school['name'],
          '_school_city': school['city'],
        });
      }
    }
    return all;
  }

  /// Tous les teachers de TOUTES les écoles gérées
  static Future<List<Map<String, dynamic>>> getTeachersForAdmin({
    required Teacher admin,
    String? filterSchoolName,
    String? filterSchoolCity,
  }) async {
    final db = await database;
    final schools = admin.allManagedSchools;

    if (filterSchoolName != null && filterSchoolCity != null) {
      return getTeachersBySchool(
        schoolName: filterSchoolName,
        schoolCity: filterSchoolCity,
      );
    }

    final List<Map<String, dynamic>> all = [];
    for (final school in schools) {
      final teachers = await getTeachersBySchool(
        schoolName: school['name']!,
        schoolCity: school['city']!,
      );
      for (final t in teachers) {
        all.add({
          ...t,
          '_school_name': school['name'],
          '_school_city': school['city'],
        });
      }
    }
    return all;
  }

  // ── Queries existantes (inchangées) ─────────────────────

  static Future<List<Map<String, dynamic>>> getAllStudentsInSchool({
    required String schoolName,
    required String schoolCity,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT ch.* FROM children ch
      INNER JOIN classes cl ON ch.class_id = cl.id
      WHERE cl.school_name = ? AND cl.school_city = ? AND ch.deleted = 0
      ORDER BY ch.first_name ASC
    ''',
      [schoolName, schoolCity],
    );
  }

  static Future<List<Map<String, dynamic>>> getAllChildrenWithDetails({
    required String schoolName,
    required String schoolCity,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        ch.id, ch.child_code, ch.first_name, ch.last_name, ch.gender,
        ch.birth_date, ch.latest_overall_risk_level, ch.latest_observation_date, ch.notes,
        cl.name AS class_name, cl.level AS class_level,
        t.first_name AS teacher_first_name, t.last_name AS teacher_last_name,
        t.email AS teacher_email
      FROM children ch
      INNER JOIN classes cl ON ch.class_id = cl.id
      INNER JOIN teachers t ON ch.main_teacher_id = t.id
      WHERE t.school_name = ? AND t.school_city = ?
        AND t.deleted = 0 AND ch.deleted = 0
      ORDER BY t.first_name ASC, ch.first_name ASC
    ''',
      [schoolName, schoolCity],
    );
  }

  static Future<int> countChildrenInSchool({
    required String schoolName,
    required String schoolCity,
  }) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt FROM children ch
      INNER JOIN teachers t ON ch.main_teacher_id = t.id
      WHERE t.school_name = ? AND t.school_city = ? AND t.deleted = 0 AND ch.deleted = 0
    ''',
      [schoolName, schoolCity],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getTeachersBySchool({
    required String schoolName,
    required String schoolCity,
  }) async {
    final db = await database;
    return await db.query(
      'teachers',
      where: 'deleted = 0 AND school_name = ? AND school_city = ?',
      whereArgs: [schoolName, schoolCity],
      orderBy: 'role ASC, first_name ASC',
    );
  }

  static Future<void> updateTeacher({
    required int teacherId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {...data, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  static Future<void> setTeacherRole({
    required int teacherId,
    required String role,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {'role': role, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  static Future<void> setTeacherActive({
    required int teacherId,
    required bool isActive,
  }) async {
    final db = await database;
    await db.update(
      'teachers',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  static Future<void> archiveTeacher(int teacherId) async {
    final db = await database;
    await db.update(
      'teachers',
      {'deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [teacherId],
    );
  }

  static Future<void> deleteTeacher(int teacherId) async {
    final db = await database;
    await db.delete(
      'class_teachers',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    await db.delete('teachers', where: 'id = ?', whereArgs: [teacherId]);
  }

  static Future<Map<String, dynamic>> getTeacherStats(int teacherId) async {
    final db = await database;
    final classRes = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM classes c INNER JOIN class_teachers ct ON ct.class_id = c.id WHERE ct.teacher_id = ? AND c.deleted = 0',
      [teacherId],
    );
    final studentRes = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM children WHERE main_teacher_id = ? AND deleted = 0',
      [teacherId],
    );
    return {
      'classes': (classRes.first['cnt'] as int?) ?? 0,
      'students': (studentRes.first['cnt'] as int?) ?? 0,
    };
  }

  static Future<List<Map<String, dynamic>>> getClassesByTeacherInSchool({
    required int teacherId,
    required String schoolName,
    required String schoolCity,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT c.* FROM classes c INNER JOIN class_teachers ct ON ct.class_id = c.id
      WHERE ct.teacher_id = ? AND c.deleted = 0 AND c.school_name = ? AND c.school_city = ?
      ORDER BY c.name ASC
    ''',
      [teacherId, schoolName, schoolCity],
    );
  }

  static Future<List<Map<String, dynamic>>> getStudentsByClassInSchool({
    required int classId,
    required String schoolName,
    required String schoolCity,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT ch.* FROM children ch INNER JOIN classes c ON c.id = ch.class_id
      WHERE ch.class_id = ? AND ch.deleted = 0 AND c.school_name = ? AND c.school_city = ?
      ORDER BY ch.first_name ASC
    ''',
      [classId, schoolName, schoolCity],
    );
  }

  static Future<void> updateStudent({
    required int studentId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    await db.update(
      'children',
      {...data, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }
}
