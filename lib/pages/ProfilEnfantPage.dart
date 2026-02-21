import 'package:flutter/material.dart';
import '../services/db_service.dart';
import 'ChecklistObservationPage.dart';

class ProfilEnfantPage extends StatefulWidget {
  final int studentId;
  final int teacherId;
  final int classId;

  const ProfilEnfantPage({
    super.key,
    required this.studentId,
    required this.teacherId,
    required this.classId,
  });

  @override
  State<ProfilEnfantPage> createState() => _ProfilEnfantPageState();
}

class _ProfilEnfantPageState extends State<ProfilEnfantPage> {
  late Future<Map<String, dynamic>?> futureStudent;
  late Future<List<Map<String, dynamic>>> futureObservations;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    futureStudent = DBService.getStudentById(widget.studentId);
    futureObservations = DBService.getObservationsByStudent(widget.studentId);
    setState(() {});
  }

  String riskLabel(String? risk) {
    if (risk == null || risk.isEmpty) return "Non défini";
    if (risk == "green") return "Vert";
    if (risk == "orange") return "Orange";
    if (risk == "red") return "Rouge";
    return risk;
  }

  Color riskColor(String? risk) {
    switch ((risk ?? "").toLowerCase()) {
      case "green":
        return Colors.green;
      case "orange":
        return Colors.orange;
      case "red":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return "${d.day.toString().padLeft(2, '0')}/"
          "${d.month.toString().padLeft(2, '0')}/"
          "${d.year}";
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Profil enfant"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Info élève
            FutureBuilder<Map<String, dynamic>?>(
              future: futureStudent,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }

                final student = snap.data;
                if (student == null) return const Text("Élève introuvable ❌");

                final fullName =
                    "${student['first_name'] ?? ''} ${student['last_name'] ?? ''}"
                        .trim();
                final risk = student['latest_overall_risk_level']?.toString();

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? "Enfant" : fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text("Dernier niveau : "),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: riskLabel(risk),
                            color: riskColor(risk),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Bouton pour ajouter observation
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Ajouter une observation"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NouvelleObservationChecklistPage(
                        childId: widget.studentId,
                        teacherId: widget.teacherId,
                        classId: widget.classId,
                      ),
                    ),
                  );

                  // Si une observation a été ajoutée, on rafraîchit
                  if (result == true) {
                    _refresh();
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Liste des observations
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: futureObservations,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.orange),
                    );
                  }

                  final obs = snap.data ?? [];
                  if (obs.isEmpty) {
                    return const Center(child: Text("Aucune observation."));
                  }

                  return ListView.builder(
                    itemCount: obs.length,
                    itemBuilder: (context, i) {
                      final o = obs[i];
                      final date = o['date']?.toString() ?? "";
                      final risk = o['overall_risk_level']?.toString();
                      final notes = o['notes']?.toString() ?? "";
                      final contextObs = o['context']?.toString() ?? "";

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(color: riskColor(risk), width: 6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formatDate(date)),
                                StatusChip(
                                  label: riskLabel(risk),
                                  color: riskColor(risk),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Contexte : $contextObs"),
                            const SizedBox(height: 4),
                            Text("Notes : $notes"),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
