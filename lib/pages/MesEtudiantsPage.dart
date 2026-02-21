import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/sync_engine.dart'; // ✅ Fix 1 : pour sync Firebase

class MesEtudiantsPage extends StatefulWidget {
  final int teacherId;
  const MesEtudiantsPage({super.key, required this.teacherId});

  @override
  State<MesEtudiantsPage> createState() => _MesEtudiantsPageState();
}

class _MesEtudiantsPageState extends State<MesEtudiantsPage> {
  late Future<List<Map<String, dynamic>>> futureStudents;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    futureStudents = DBService.getActiveStudentsByTeacher(widget.teacherId);
    setState(() {});
  }

  // ✅ Fix 1 : archive → synced=0 → SyncEngine propage à Firebase
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

    // 1. SQLite : deleted=1, synced=0
    await DBService.archiveStudent(s['id']);

    // ✅ Fix 1 : marquer synced=0 pour que SyncEngine propage à Firebase
    await SyncEngine.markUnsync('children', s['id']);

    // 2. Tenter sync immédiate si en ligne
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
      ),
      body: Center(
        child: SizedBox(
          width: maxWidth,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: futureStudents,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erreur : ${snapshot.error}"));
                }

                final students = snapshot.data ?? [];

                if (students.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aucun étudiant trouvé.",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return _StudentCard(
                      student: s,
                      onArchive: () => _archiveStudent(s),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Widget carte étudiant
// ─────────────────────────────────────────────────────────
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

    // ✅ Fix 2 : genre correct (male/female au lieu de boy/girl)
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
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isFemale ? Icons.face_3 : Icons.face, // ✅ Fix 2
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),

          // Infos
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

          // Bouton archive
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
        return Colors.grey;
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
