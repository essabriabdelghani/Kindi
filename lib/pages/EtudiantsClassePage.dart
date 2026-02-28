import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/db_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_down_service.dart';
import 'ProfilEnfantPage.dart';

class EtudiantsClassePage extends StatefulWidget {
  final int classId;
  final String className;
  final int mainTeacherId;

  const EtudiantsClassePage({
    super.key,
    required this.classId,
    required this.className,
    required this.mainTeacherId,
  });

  @override
  State<EtudiantsClassePage> createState() => _EtudiantsClassePageState();
}

class _EtudiantsClassePageState extends State<EtudiantsClassePage> {
  Future<List<Map<String, dynamic>>> futureStudents = Future.value([]);
  bool showArchived = false;
  bool _syncing = true;

  @override
  void initState() {
    super.initState();
    _syncThenLoad();
  }

  Future<void> _syncThenLoad() async {
    if (mounted) setState(() => _syncing = true);
    if (mounted)
      setState(() {
        futureStudents = Future.value([]);
      });

    final report = await SyncDownService.syncForClass(
      teacherId: widget.mainTeacherId,
      classId: widget.classId,
    );

    if (report.hasChanges && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(report.message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _syncing = false;
        futureStudents = showArchived
            ? DBService.getArchivedStudentsByClass(widget.classId)
            : DBService.getStudentsByClass(widget.classId);
      });
    }
  }

  void _refreshStudents() {
    if (!mounted) return;
    setState(() {
      futureStudents = showArchived
          ? DBService.getArchivedStudentsByClass(widget.classId)
          : DBService.getStudentsByClass(widget.classId);
    });
  }

  Color _riskColor(String? risk) {
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

  String _riskLabel(String? risk) {
    switch (risk) {
      case 'green':
        return 'Faible';
      case 'orange':
        return 'Modéré';
      case 'red':
        return 'Élevé';
      default:
        return 'Non défini';
    }
  }

  Future<void> _showAddStudentDialog() async {
    // ✅ Capturer t AVANT d'ouvrir le dialog — context est valide ici
    final t = AppLocalizations.of(context)!;

    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final birthDateCtrl = TextEditingController();
    String gender = 'boy';
    String? riskLevel;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.addStudent),
        content: StatefulBuilder(
          builder: (ctx, setD) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameCtrl,
                  decoration: InputDecoration(
                    labelText: t.firstName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastNameCtrl,
                  decoration: InputDecoration(
                    labelText: t.lastName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: birthDateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: t.dateOfBirth,
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(2018),
                      firstDate: DateTime(2005),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      birthDateCtrl.text = picked.toIso8601String().split(
                        'T',
                      )[0];
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: InputDecoration(
                    labelText: t.gender,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'boy', child: Text(t.boy)),
                    DropdownMenuItem(value: 'girl', child: Text(t.girl)),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => gender = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: riskLevel,
                  decoration: InputDecoration(
                    labelText: t.riskLevel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text(t.riskUndefined)),
                    DropdownMenuItem(
                      value: 'green',
                      child: const Text("🟢 Faible"),
                    ),
                    DropdownMenuItem(
                      value: 'orange',
                      child: const Text("🟠 Modéré"),
                    ),
                    DropdownMenuItem(
                      value: 'red',
                      child: const Text("🔴 Élevé"),
                    ),
                  ],
                  onChanged: (v) => setD(() => riskLevel = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final firstName = firstNameCtrl.text.trim();
              final birthDate = birthDateCtrl.text.trim();

              if (firstName.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text("${t.firstName} obligatoire ❌")),
                );
                return;
              }
              if (birthDate.isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text(t.dateOfBirthRequired)));
                return;
              }

              try {
                await DBService.insertStudent(
                  firstName: firstName,
                  lastName: lastNameCtrl.text.trim(),
                  birthDate: birthDate,
                  gender: gender,
                  classId: widget.classId,
                  mainTeacherId: widget.mainTeacherId,
                  riskLevel: riskLevel,
                );
                SyncEngine.syncAll(teacherId: widget.mainTeacherId);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("${t.students} ✅"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _refreshStudents();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(
                    ctx,
                  ).showSnackBar(SnackBar(content: Text("${t.error} : $e")));
                }
              }
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              t.addStudent,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ t dans build() — toujours safe
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text("${t.students} — ${widget.className}"),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: t.synchronizing,
              onPressed: _syncThenLoad,
            ),
          IconButton(
            icon: Icon(showArchived ? Icons.list : Icons.archive),
            onPressed: () => setState(() {
              showArchived = !showArchived;
              _refreshStudents();
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _syncing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.orange),
                  const SizedBox(height: 15),
                  Text(
                    t.synchronizing,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: futureStudents,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text("${t.error} : ${snapshot.error}"));
                }

                final students = snapshot.data ?? [];

                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.child_care,
                          size: 60,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          showArchived ? t.noArchivedStudents : t.noStudents,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        if (!showArchived) ...[
                          const SizedBox(height: 8),
                          Text(
                            t.noStudentsHint,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: Colors.orange,
                  onRefresh: _syncThenLoad,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final s = students[index];
                      final firstName = s['first_name'] ?? '';
                      final lastName = s['last_name'] ?? '';
                      final fullName = '$firstName $lastName'.trim();
                      final risk = s['latest_overall_risk_level']?.toString();

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilEnfantPage(
                              studentId: s['id'],
                              teacherId: widget.mainTeacherId,
                              classId: widget.classId,
                            ),
                          ),
                        ).then((_) => _syncThenLoad()),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: _riskColor(
                                  risk,
                                ).withOpacity(0.15),
                                child: Icon(
                                  s['gender'] == 'girl'
                                      ? Icons.face_3
                                      : Icons.face,
                                  color: _riskColor(risk),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.isEmpty ? t.students : fullName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: _riskColor(risk),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${t.riskLevel} : ${_riskLabel(risk)}",
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'archive') {
                                    await DBService.archiveStudent(s['id']);
                                    await SyncEngine.markUnsync(
                                      'children',
                                      s['id'],
                                    );
                                    SyncEngine.syncAll(
                                      teacherId: widget.mainTeacherId,
                                    );
                                    _refreshStudents();
                                  } else if (value == 'unarchive') {
                                    await DBService.unarchiveStudent(s['id']);
                                    _refreshStudents();
                                  } else if (value == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(t.confirmDelete),
                                        content: Text(
                                          "${t.delete} $fullName ?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text(t.cancel),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text(t.delete),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await DBService.deleteStudent(s['id']);
                                      SyncEngine.syncAll(
                                        teacherId: widget.mainTeacherId,
                                      );
                                      _refreshStudents();
                                    }
                                  }
                                },
                                itemBuilder: (_) => showArchived
                                    ? [
                                        PopupMenuItem(
                                          value: 'unarchive',
                                          child: Text(t.unarchive),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(t.delete),
                                        ),
                                      ]
                                    : [
                                        PopupMenuItem(
                                          value: 'archive',
                                          child: Text(t.archive),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(t.delete),
                                        ),
                                      ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
