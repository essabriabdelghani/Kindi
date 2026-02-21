import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/children.dart';

class FormulaireObservationPage extends StatefulWidget {
  final Child child;

  const FormulaireObservationPage({super.key, required this.child});

  @override
  State<FormulaireObservationPage> createState() =>
      _FormulaireObservationPageState();
}

class _FormulaireObservationPageState extends State<FormulaireObservationPage> {
  // ======= Champs du formulaire =======
  String contexte = "Regroupement";
  String reponseQ1 = "Jamais";
  String reponseQ2 = "Jamais";
  String reponseQ3 = "Jamais";

  final TextEditingController noteController = TextEditingController();

  late final String dateObservation;

  @override
  void initState() {
    super.initState();
    dateObservation = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double maxWidth = width > 800 ? 800 : width * 0.95;

    final child = widget.child;
    final fullName = "${child.firstName} ${child.lastName ?? ''}".trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),

      appBar: AppBar(
        backgroundColor: Colors.orange,
        elevation: 0,
        title: const Text("Nouvelle observation"),
      ),

      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: maxWidth,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Infos enfant
                  infoCard(
                    fullName: fullName,
                    childCode: child.childCode,
                    gender: child.gender,
                    classId: child.classId,
                    dateObservation: dateObservation,
                  ),

                  const SizedBox(height: 25),

                  // 🔹 CONTEXTE
                  sectionTitle("Contexte"),
                  contextDropdown(),

                  const SizedBox(height: 25),

                  // 🔹 QUESTION 1
                  sectionTitle("1. A du mal à rester concentré"),
                  choiceGroup(
                    value: reponseQ1,
                    onChanged: (val) => setState(() => reponseQ1 = val!),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 QUESTION 2
                  sectionTitle("2. Interrompt souvent les autres"),
                  choiceGroup(
                    value: reponseQ2,
                    onChanged: (val) => setState(() => reponseQ2 = val!),
                  ),

                  const SizedBox(height: 20),

                  // 🔹 QUESTION 3
                  sectionTitle("3. A du mal à suivre les consignes"),
                  choiceGroup(
                    value: reponseQ3,
                    onChanged: (val) => setState(() => reponseQ3 = val!),
                  ),

                  const SizedBox(height: 25),

                  // 🔹 Notes
                  sectionTitle("Notes (optionnel)"),
                  notesField(),

                  const SizedBox(height: 40),

                  // 🔹 BOUTON SOUMETTRE
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _submitObservation,
                      label: const Text(
                        "Soumettre l'observation",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // 🔹 Submit
  // =====================================================
  void _submitObservation() {
    // Exemple: récupérer toutes les valeurs
    final observationData = {
      "child_id": widget.child.id,
      "class_id": widget.child.classId,
      "teacher_id": widget.child.mainTeacherId,
      "date": DateTime.now().toIso8601String(),
      "contexte": contexte,
      "q1": reponseQ1,
      "q2": reponseQ2,
      "q3": reponseQ3,
      "notes": noteController.text.trim(),
    };

    // Pour l'instant juste affichage (après tu connectes DB)
    debugPrint("Observation envoyée: $observationData");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Observation soumise avec succès"),
        backgroundColor: Colors.orange,
      ),
    );

    Navigator.pop(context);
  }

  // =====================================================
  // 🔹 Widgets UI
  // =====================================================

  Widget infoCard({
    required String fullName,
    required String? childCode,
    required String gender,
    required int classId,
    required String dateObservation,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        border: Border.all(color: Colors.orange.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.child_care, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Code enfant
          if (childCode != null && childCode!.isNotEmpty)
            Text("Code : $childCode", style: const TextStyle(fontSize: 15)),

          const SizedBox(height: 6),

          // Gender + Classe
          Row(
            children: [
              Icon(
                gender == 'girl' ? Icons.female : Icons.male,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                gender == 'girl' ? "Fille" : "Garçon",
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.school, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                "Classe ID : $classId",
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text("Date : $dateObservation", style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget contextDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: DropdownButton<String>(
        value: contexte,
        isExpanded: true,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: "Regroupement", child: Text("Regroupement")),
          DropdownMenuItem(value: "Jeu libre", child: Text("Jeu libre")),
          DropdownMenuItem(value: "Activité", child: Text("Activité")),
          DropdownMenuItem(value: "Récréation", child: Text("Récréation")),
        ],
        onChanged: (value) {
          setState(() {
            contexte = value!;
          });
        },
      ),
    );
  }

  Widget notesField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: TextField(
        controller: noteController,
        maxLines: 4,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.all(15),
          border: InputBorder.none,
          hintText: "Ajouter une note...",
        ),
      ),
    );
  }

  Widget choiceGroup({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      children: ["Jamais", "Parfois", "Souvent"].map((choice) {
        return RadioListTile<String>(
          value: choice,
          groupValue: value,
          title: Text(choice),
          activeColor: Colors.orange,
          onChanged: onChanged,
        );
      }).toList(),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
