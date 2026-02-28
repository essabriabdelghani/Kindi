import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
  // ✅ Valeurs initiales hardcodées (clés neutres) — traduits dans build()
  String _contexteKey = 'grouping'; // clé, pas texte traduit
  String _reponseQ1Key = 'never';
  String _reponseQ2Key = 'never';
  String _reponseQ3Key = 'never';

  final TextEditingController _noteController = TextEditingController();
  late final String _dateObservation;

  @override
  void initState() {
    super.initState();
    _dateObservation = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ✅ Helper — traduit une clé en texte localisé
  String _tContext(AppLocalizations t, String key) {
    switch (key) {
      case 'grouping':
        return t.grouping;
      case 'freePlay':
        return t.freePlay;
      case 'activity':
        return t.activity;
      default:
        return key;
    }
  }

  String _tFreq(AppLocalizations t, String key) {
    switch (key) {
      case 'never':
        return t.never;
      case 'sometimes':
        return t.sometimes;
      case 'often':
        return t.often;
      default:
        return key;
    }
  }

  void _submitObservation(AppLocalizations t) {
    final observationData = {
      'child_id': widget.child.id,
      'class_id': widget.child.classId,
      'teacher_id': widget.child.mainTeacherId,
      'date': DateTime.now().toIso8601String(),
      'contexte': _contexteKey,
      'q1': _reponseQ1Key,
      'q2': _reponseQ2Key,
      'q3': _reponseQ3Key,
      'notes': _noteController.text.trim(),
    };
    debugPrint('Observation envoyée: $observationData');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.observationSaved),
        backgroundColor: Colors.orange,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ t disponible ici — tout passe par build()
    final t = AppLocalizations.of(context)!;
    final child = widget.child;
    final fullName = '${child.firstName} ${child.lastName ?? ''}'.trim();
    final double maxWidth = MediaQuery.of(context).size.width > 800
        ? 800
        : MediaQuery.of(context).size.width * 0.95;

    // Options contexte
    final contextOptions = [
      {'key': 'grouping', 'label': t.grouping},
      {'key': 'freePlay', 'label': t.freePlay},
      {'key': 'activity', 'label': t.activity},
    ];

    // Options fréquence
    final freqOptions = [
      {'key': 'never', 'label': t.never},
      {'key': 'sometimes', 'label': t.sometimes},
      {'key': 'often', 'label': t.often},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        elevation: 0,
        title: Text(t.newObservation),
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
                  _infoCard(t, fullName, child),
                  const SizedBox(height: 25),

                  // 🔹 Contexte
                  _sectionTitle(t.context),
                  _contextDropdown(t, contextOptions),
                  const SizedBox(height: 25),

                  // 🔹 Questions
                  _sectionTitle(
                    '1. ${t.answerAllQuestions.contains('all') ? "A du mal à rester concentré" : "A du mal à rester concentré"}',
                  ),
                  _choiceGroup(
                    freqOptions,
                    _reponseQ1Key,
                    (val) => setState(() => _reponseQ1Key = val!),
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('2. Interrompt souvent les autres'),
                  _choiceGroup(
                    freqOptions,
                    _reponseQ2Key,
                    (val) => setState(() => _reponseQ2Key = val!),
                  ),
                  const SizedBox(height: 20),

                  _sectionTitle('3. A du mal à suivre les consignes'),
                  _choiceGroup(
                    freqOptions,
                    _reponseQ3Key,
                    (val) => setState(() => _reponseQ3Key = val!),
                  ),
                  const SizedBox(height: 25),

                  // 🔹 Notes
                  _sectionTitle(t.notesOptional),
                  _notesField(t),
                  const SizedBox(height: 40),

                  // 🔹 Bouton soumettre
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
                      onPressed: () => _submitObservation(t),
                      label: Text(t.save, style: const TextStyle(fontSize: 18)),
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

  Widget _infoCard(AppLocalizations t, String fullName, Child child) {
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
          if (child.childCode != null && child.childCode!.isNotEmpty)
            Text(
              'Code : ${child.childCode}',
              style: const TextStyle(fontSize: 15),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                child.gender == 'girl' ? Icons.female : Icons.male,
                color: Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                child.gender == 'girl' ? t.girl : t.boy,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.school, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                'Classe ID : ${child.classId}',
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Date : $_dateObservation',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _contextDropdown(
    AppLocalizations t,
    List<Map<String, String>> options,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: DropdownButton<String>(
        value: _contexteKey,
        isExpanded: true,
        underline: const SizedBox(),
        items: options
            .map(
              (o) =>
                  DropdownMenuItem(value: o['key'], child: Text(o['label']!)),
            )
            .toList(),
        onChanged: (val) => setState(() => _contexteKey = val!),
      ),
    );
  }

  Widget _notesField(AppLocalizations t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: TextField(
        controller: _noteController,
        maxLines: 4,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none,
          hintText: t.addNote,
        ),
      ),
    );
  }

  Widget _choiceGroup(
    List<Map<String, String>> options,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      children: options.map((o) {
        return RadioListTile<String>(
          value: o['key']!,
          groupValue: value,
          title: Text(o['label']!),
          activeColor: Colors.orange,
          onChanged: onChanged,
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
