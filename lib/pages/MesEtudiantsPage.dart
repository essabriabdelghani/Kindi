import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_down_service.dart'; // ✅ sync descendante

class MesEtudiantsPage extends StatefulWidget {
  final int teacherId;
  const MesEtudiantsPage({super.key, required this.teacherId});

  @override
  State<MesEtudiantsPage> createState() => _MesEtudiantsPageState();
}

class _MesEtudiantsPageState extends State<MesEtudiantsPage> {
  // ✅ Pas de late — initialisé directement
  Future<List<Map<String, dynamic>>> futureStudents = Future.value([]);
  bool _syncing = true;

  @override
  void initState() {
    super.initState();
    _syncThenLoad();
  }

  // ✅ Sync descendante Firebase → SQLite puis afficher
  Future<void> _syncThenLoad() async {
    if (mounted) setState(() => _syncing = true);

    await SyncDownService.syncForTeacher(
      teacherId: widget.teacherId,
      schoolName: '', // sera ignoré si déjà en SQLite
      schoolCity: '',
    );

    _refresh();
    if (mounted) setState(() => _syncing = false);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      futureStudents = DBService.getActiveStudentsByTeacher(widget.teacherId);
    });
  }

  Future<void> _archiveStudent(Map<String, dynamic> s) async {
    final firstName = s['first_name'] ?? '';
    final lastName = s['last_name'] ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Archiver l'étudiant"),
        content: Text("Voulez-vous archiver '$firstName $lastName' ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Archiver"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await DBService.archiveStudent(s['id']);
    await SyncEngine.markUnsync('children', s['id']);
    SyncEngine.syncAll(teacherId: widget.teacherId);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 800 ? 800.0 : width * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Mes étudiants"),
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
              tooltip: "Synchroniser",
              onPressed: _syncThenLoad,
            ),
        ],
      ),
      body: _syncing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 15),
                  Text(
                    "Synchronisation...",
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          : Center(
              child: SizedBox(
                width: maxWidth,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: futureStudents,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text("Erreur : ${snapshot.error}"),
                        );
                      }

                      final students = snapshot.data ?? [];

                      if (students.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.child_care,
                                size: 60,
                                color: Colors.orange,
                              ),
                              SizedBox(height: 15),
                              Text(
                                "Aucun étudiant trouvé.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: Colors.orange,
                        onRefresh: _syncThenLoad,
                        child: ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final s = students[index];
                            return _StudentCard(
                              student: s,
                              onArchive: () => _archiveStudent(s),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onArchive;

  const _StudentCard({required this.student, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    final firstName = student['first_name'] ?? '';
    final lastName = student['last_name'] ?? '';
    final gender = student['gender'] ?? '';
    final className = student['class_name'] ?? '';
    final risk = student['latest_overall_risk_level'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    final isFemale = gender == 'female' || gender == 'girl' || gender == 'F';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _riskColor(risk).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isFemale ? Icons.face_3 : Icons.face,
              color: _riskColor(risk).withOpacity(0.8),
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Étudiant' : fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (className.isNotEmpty)
                  Text(
                    "Classe : $className",
                    style: const TextStyle(color: Colors.black54),
                  ),
                if (risk.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: _riskColor(risk),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        "Risque : ${_riskLabel(risk)}",
                        style: TextStyle(
                          color: _riskColor(risk),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.archive, color: Colors.red),
            tooltip: 'Archiver',
            onPressed: onArchive,
          ),
        ],
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
        return Colors.orange;
    }
  }

  String _riskLabel(String risk) {
    switch (risk) {
      case 'green':
        return 'Faible';
      case 'orange':
        return 'Modéré';
      case 'red':
        return 'Élevé';
      default:
        return risk;
    }
  }
}
