import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/db_service.dart';

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
    refreshStudents();
  }

  void refreshStudents() {
    futureStudents = DBService.getActiveStudentsByTeacher(widget.teacherId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double maxWidth = width > 800 ? 800 : width * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(AppLocalizations.of(context)!.myStudents),
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
                  return Center(
                    child: Text(
                      AppLocalizations.of(context)!.noStudents,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final s = students[index];

                    final firstName = s['first_name'] ?? '';
                    final lastName = s['last_name'] ?? '';
                    final gender = s['gender'] ?? '';
                    final className = s['class_name'] ?? '';
                    final risk = s['latest_overall_risk_level'] ?? '';

                    return studentCard(
                      fullName: "$firstName $lastName".trim(),
                      gender: gender,
                      className: className,
                      riskLevel: risk,
                      onArchive: () async {
                        bool? confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Archiver l’étudiant"),
                            content: Text(
                              "Voulez-vous archiver '$firstName $lastName' ?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  AppLocalizations.of(context)!.cancel,
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  AppLocalizations.of(context)!.archive,
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await DBService.archiveStudent(s['id']);
                          refreshStudents();
                        }
                      },
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

  Widget studentCard({
    required String fullName,
    required String gender,
    required String className,
    required String riskLevel,
    required VoidCallback onArchive,
  }) {
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
          // avatar / icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              gender == "girl" ? Icons.face_3 : Icons.face,
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),

          // infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (className.toString().isNotEmpty)
                  Text(
                    "Classe : $className",
                    style: const TextStyle(color: Colors.black54),
                  ),
                if (riskLevel.toString().isNotEmpty)
                  Text(
                    "Risque : $riskLevel",
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ),

          // archive button
          IconButton(
            icon: const Icon(Icons.archive, color: Colors.red),
            onPressed: onArchive,
          ),
        ],
      ),
    );
  }
}
