import 'package:flutter/material.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../controllers/auth_controller.dart'; // ✅ Fix 3 : pour changeRole

class AdminPage extends StatefulWidget {
  final Teacher admin;
  const AdminPage({super.key, required this.admin});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<List<Map<String, dynamic>>> futureTeachers;

  @override
  void initState() {
    super.initState();
    _refreshTeachers();
  }

  void _refreshTeachers() {
    futureTeachers = DBService.getTeachersBySchool(
      // ✅ Fix 1 : schoolName et schoolCity ne sont PAS nullable dans Teacher
      // donc pas besoin de ! — mais on les garde car le compilateur peut
      // inférer non-null depuis widget.admin (qui est non-null lui-même)
      schoolName: widget.admin.schoolName,
      schoolCity: widget.admin.schoolCity,
    );
    setState(() {});
  }

  // ====== ADD / EDIT TEACHER DIALOG ======
  Future<void> _openTeacherForm({Map<String, dynamic>? teacher}) async {
    final isEdit = teacher != null;

    final firstNameCtrl = TextEditingController(
      text: teacher?['first_name'] ?? "",
    );
    final lastNameCtrl = TextEditingController(
      text: teacher?['last_name'] ?? "",
    );
    final emailCtrl = TextEditingController(text: teacher?['email'] ?? "");
    final phoneCtrl = TextEditingController(
      text: teacher?['phone_number'] ?? "",
    );
    final expCtrl = TextEditingController(
      text: teacher?['years_of_experience']?.toString() ?? "",
    );

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Modifier professeur" : "Ajouter professeur"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(labelText: "Prénom"),
              ),
              TextField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(labelText: "Nom"),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "Téléphone"),
              ),
              TextField(
                controller: expCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Années d'expérience",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(isEdit ? "Enregistrer" : "Ajouter"),
            onPressed: () async {
              final firstName = firstNameCtrl.text.trim();
              final email = emailCtrl.text.trim();

              if (firstName.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Prénom et email obligatoires ❌"),
                  ),
                );
                return;
              }

              if (isEdit) {
                await DBService.updateTeacher(
                  teacherId: teacher['id'],
                  data: {
                    "first_name": firstNameCtrl.text.trim(),
                    "last_name": lastNameCtrl.text.trim(),
                    "email": emailCtrl.text.trim(),
                    "phone_number": phoneCtrl.text.trim(),
                    "years_of_experience":
                        int.tryParse(expCtrl.text.trim()) ?? 0,
                    "synced": 0, // ✅ Fix 2 : marquer pour sync Firebase
                  },
                );
              } else {
                final newTeacher = Teacher(
                  id: null,
                  firstName: firstNameCtrl.text.trim(),
                  lastName: lastNameCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  schoolName: widget.admin.schoolName, // ✅ Fix 1 : sans !
                  schoolCity: widget.admin.schoolCity, // ✅ Fix 1 : sans !
                  schoolRegion: widget.admin.schoolRegion,
                  role: "teacher",
                  preferredLanguage: "fr",
                  yearsOfExperience: int.tryParse(expCtrl.text.trim()) ?? 0,
                  gradeLevel: null,
                  passwordHash:
                      "1234", // ⚠️ à changer — envoyer un email d'invitation
                  isActive: 1,
                  synced: 0, // ✅ Fix 2 : 0 pour déclencher sync Firebase
                  deleted: 0,
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                );

                final ok = await DBService.insertTeacher(newTeacher);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Email déjà utilisé ❌")),
                  );
                  return;
                }
              }

              if (context.mounted) Navigator.pop(context);
              _refreshTeachers();
            },
          ),
        ],
      ),
    );
  }

  // ====== ACTIVATE / DEACTIVATE ======
  Future<void> _toggleTeacherActive(Map<String, dynamic> teacher) async {
    final current = teacher['is_active'] == 1;
    await DBService.setTeacherActive(
      teacherId: teacher['id'],
      isActive: !current,
    );
    _refreshTeachers();
  }

  // ====== ARCHIVE ======
  Future<void> _archiveTeacher(Map<String, dynamic> teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Archiver professeur"),
        content: const Text("Voulez-vous archiver ce professeur ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Oui"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBService.archiveTeacher(teacher['id']);
      _refreshTeachers();
    }
  }

  // ====== CHANGER RÔLE ====== ✅ Fix 3 : nouvelle fonctionnalité
  Future<void> _changeRole(Map<String, dynamic> teacher) async {
    final currentRole = teacher['role'] ?? 'teacher';
    String selectedRole = currentRole;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text("Changer le rôle de ${teacher['first_name']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['teacher', 'admin', 'super_admin'].map((role) {
              return RadioListTile<String>(
                title: Text(_roleLabel(role)),
                value: role,
                groupValue: selectedRole,
                activeColor: Colors.orange,
                onChanged: (v) => setDialogState(() => selectedRole = v!),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Confirmer"),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && selectedRole != currentRole) {
      final ok = await AuthController.changeRole(
        currentUser: widget.admin,
        targetTeacherId: teacher['id'],
        newRole: selectedRole,
      );
      if (ok) {
        _refreshTeachers();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Rôle mis à jour → ${_roleLabel(selectedRole)} ✅"),
            ),
          );
        }
      }
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return '🔑 Administrateur';
      case 'super_admin':
        return '👑 Super Admin';
      default:
        return '👤 Professeur';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Administration"),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
        onPressed: () => _openTeacherForm(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: futureTeachers,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              );
            }

            final teachers = snap.data ?? [];
            if (teachers.isEmpty) {
              return const Center(child: Text("Aucun professeur trouvé."));
            }

            return ListView.builder(
              itemCount: teachers.length,
              itemBuilder: (context, i) {
                final t = teachers[i];
                final fullName =
                    "${t['first_name'] ?? ''} ${t['last_name'] ?? ''}".trim();
                final active = t['is_active'] == 1;
                final role = t['role'] ?? 'teacher';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    title: Text(fullName.isEmpty ? "Professeur" : fullName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['email'] ?? ""),
                        Text(
                          _roleLabel(role),
                          style: TextStyle(
                            fontSize: 11,
                            color: role == 'admin' ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == "edit") _openTeacherForm(teacher: t);
                        if (value == "toggle") _toggleTeacherActive(t);
                        if (value == "archive") _archiveTeacher(t);
                        if (value == "role") _changeRole(t); // ✅ Fix 3
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: "edit",
                          child: Text("✏️ Modifier"),
                        ),
                        PopupMenuItem(
                          value: "toggle",
                          child: Text(active ? "🔕 Désactiver" : "✅ Activer"),
                        ),
                        const PopupMenuItem(
                          value: "role",
                          child: Text("🎭 Changer rôle"),
                        ), // ✅ Fix 3
                        const PopupMenuItem(
                          value: "archive",
                          child: Text("🗃️ Archiver"),
                        ),
                      ],
                    ),
                    leading: CircleAvatar(
                      backgroundColor: active ? Colors.green : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminTeacherClassesPage(
                            admin: widget.admin,
                            teacher: t,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================
// PAGE 2 : Classes du prof (inchangée, déjà correcte)
// ===========================================================
class AdminTeacherClassesPage extends StatefulWidget {
  final Teacher admin;
  final Map<String, dynamic> teacher;

  const AdminTeacherClassesPage({
    super.key,
    required this.admin,
    required this.teacher,
  });

  @override
  State<AdminTeacherClassesPage> createState() =>
      _AdminTeacherClassesPageState();
}

class _AdminTeacherClassesPageState extends State<AdminTeacherClassesPage> {
  late Future<List<Map<String, dynamic>>> futureClasses;

  @override
  void initState() {
    super.initState();
    futureClasses = DBService.getClassesByTeacherInSchool(
      teacherId: widget.teacher['id'],
      schoolName: widget.admin.schoolName, // ✅ Fix 1 : sans !
      schoolCity: widget.admin.schoolCity, // ✅ Fix 1 : sans !
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        "${widget.teacher['first_name']} ${widget.teacher['last_name'] ?? ''}"
            .trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("Classes de $fullName"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: futureClasses,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              );
            }

            final classes = snap.data ?? [];
            if (classes.isEmpty)
              return const Center(child: Text("Aucune classe trouvée."));

            return ListView.builder(
              itemCount: classes.length,
              itemBuilder: (context, i) {
                final c = classes[i];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.class_),
                    title: Text(c['name'] ?? "Classe"),
                    subtitle: Text("Niveau: ${c['level'] ?? '-'}"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminClassStudentsPage(
                            admin: widget.admin,
                            classData: c,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================
// PAGE 3 : Élèves de la classe
// ===========================================================
class AdminClassStudentsPage extends StatefulWidget {
  final Teacher admin;
  final Map<String, dynamic> classData;

  const AdminClassStudentsPage({
    super.key,
    required this.admin,
    required this.classData,
  });

  @override
  State<AdminClassStudentsPage> createState() => _AdminClassStudentsPageState();
}

class _AdminClassStudentsPageState extends State<AdminClassStudentsPage> {
  late Future<List<Map<String, dynamic>>> futureStudents;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    futureStudents = DBService.getStudentsByClassInSchool(
      classId: widget.classData['id'],
      schoolName: widget.admin.schoolName, // ✅ Fix 1 : sans !
      schoolCity: widget.admin.schoolCity, // ✅ Fix 1 : sans !
    );
    setState(() {});
  }

  Future<void> _editStudent(Map<String, dynamic> s) async {
    final firstNameCtrl = TextEditingController(text: s['first_name'] ?? "");
    final lastNameCtrl = TextEditingController(text: s['last_name'] ?? "");
    final notesCtrl = TextEditingController(text: s['notes'] ?? "");

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier élève"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameCtrl,
              decoration: const InputDecoration(labelText: "Prénom"),
            ),
            TextField(
              controller: lastNameCtrl,
              decoration: const InputDecoration(labelText: "Nom"),
            ),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: "Notes"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              await DBService.updateStudent(
                studentId: s['id'],
                data: {
                  "first_name": firstNameCtrl.text.trim(),
                  "last_name": lastNameCtrl.text.trim(),
                  "notes": notesCtrl.text.trim(),
                  "synced": 0, // ✅ Fix 2 : marquer pour sync Firebase
                },
              );
              if (context.mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveStudent(Map<String, dynamic> s) async {
    await DBService.archiveStudent(s['id']);
    _refresh();
  }

  Future<void> _deleteStudent(Map<String, dynamic> s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer élève"),
        content: const Text("Supprimer définitivement cet élève ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Non"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Oui"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBService.deleteStudent(s['id']);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['name'] ?? "Classe";

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("Élèves - $className"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: futureStudents,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              );
            }

            final students = snap.data ?? [];
            if (students.isEmpty)
              return const Center(child: Text("Aucun élève."));

            return ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, i) {
                final s = students[i];
                final fullName =
                    "${s['first_name'] ?? ''} ${s['last_name'] ?? ''}".trim();
                final risk = s['latest_overall_risk_level'] ?? '';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _riskColor(risk).withOpacity(0.2),
                      child: Icon(Icons.child_care, color: _riskColor(risk)),
                    ),
                    title: Text(fullName.isEmpty ? "Élève" : fullName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Code: ${s['child_code'] ?? '-'}"),
                        if (risk.isNotEmpty)
                          Text(
                            "Risque : ${_riskLabel(risk)}",
                            style: TextStyle(
                              color: _riskColor(risk),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == "edit") _editStudent(s);
                        if (value == "archive") _archiveStudent(s);
                        if (value == "delete") _deleteStudent(s);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: "edit",
                          child: Text("✏️ Modifier"),
                        ),
                        PopupMenuItem(
                          value: "archive",
                          child: Text("🗃️ Archiver"),
                        ),
                        PopupMenuItem(
                          value: "delete",
                          child: Text("🗑️ Supprimer"),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'green':
        return 'Vert (faible)';
      case 'orange':
        return 'Orange (modéré)';
      case 'red':
        return 'Rouge (élevé)';
      default:
        return 'Non défini';
    }
  }
}
