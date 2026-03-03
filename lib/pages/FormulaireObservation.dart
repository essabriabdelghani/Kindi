import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/children.dart';
import '../services/db_service.dart';

class FormulaireObservationPage extends StatefulWidget {
  final Child child;
  const FormulaireObservationPage({super.key, required this.child});

  @override
  State<FormulaireObservationPage> createState() =>
      _FormulaireObservationPageState();
}

class _FormulaireObservationPageState extends State<FormulaireObservationPage> {
  String _contexteKey = 'grouping';
  final Map<int, int> answers = {}; // order_index → 0/1/2
  final TextEditingController _noteController = TextEditingController();
  late final String _dateObservation;
  late Future<List<Map<String, dynamic>>> _futureQuestions;

  @override
  void initState() {
    super.initState();
    _dateObservation = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _futureQuestions = DBService.getChecklistQuestions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _questionText(AppLocalizations t, Map<String, dynamic> q) {
    final order = q['order_index'] as int? ?? 0;
    switch (order) {
      case 1:
        return t.q1;
      case 2:
        return t.q2;
      case 3:
        return t.q3;
      case 4:
        return t.q4;
      case 5:
        return t.q5;
      case 6:
        return t.q6;
      case 7:
        return t.q7;
      case 8:
        return t.q8;
      case 9:
        return t.q9;
      case 10:
        return t.q10;
      case 11:
        return t.q11;
      case 12:
        return t.q12;
      case 13:
        return t.q13;
      case 14:
        return t.q14;
      case 15:
        return t.q15;
      case 16:
        return t.q16;
      case 17:
        return t.q17;
      case 18:
        return t.q18;
      case 19:
        return t.q19;
      case 20:
        return t.q20;
      case 21:
        return t.q21;
      case 22:
        return t.q22;
      case 23:
        return t.q23;
      case 24:
        return t.q24;
      default:
        return q['text_fr']?.toString() ?? '';
    }
  }

  Color _domainColor(int order) {
    if (order <= 9) return Colors.blue.shade600;
    if (order <= 18) return Colors.orange.shade700;
    return Colors.purple.shade600;
  }

  Future<void> _submit(
    AppLocalizations t,
    List<Map<String, dynamic>> questions,
  ) async {
    // Vérifier toutes les réponses
    for (final q in questions) {
      final order = q['order_index'] as int;
      if (!answers.containsKey(order)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.answerAllQuestions),
            backgroundColor: Colors.red.shade400,
          ),
        );
        return;
      }
    }

    // Convertir order_index → question_id pour l'insert
    final Map<int, int> answersById = {};
    for (final q in questions) {
      final id = q['id'] as int;
      final order = q['order_index'] as int;
      answersById[id] = answers[order]!;
    }

    await DBService.insertObservationChecklist(
      childId: widget.child.id!,
      teacherId: widget.child.mainTeacherId!,
      classId: widget.child.classId!,
      context: _contexteKey,
      notes: _noteController.text.trim(),
      answers: answersById,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.observationSaved),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final child = widget.child;
    final fullName = '${child.firstName} ${child.lastName ?? ''}'.trim();

    final contextOptions = [
      {'key': 'grouping', 'label': t.grouping},
      {'key': 'freePlay', 'label': t.freePlay},
      {'key': 'activity', 'label': t.activity},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t.newObservation,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureQuestions,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          final questions = snap.data ?? [];

          return Column(
            children: [
              // Barre de progression
              _progressBar(questions),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Carte infos enfant ──
                      _infoCard(t, fullName, child),
                      const SizedBox(height: 16),

                      // ── Contexte ──
                      _sectionCard(
                        icon: Icons.location_on_outlined,
                        title: t.context,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: DropdownButton<String>(
                            value: _contexteKey,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: contextOptions
                                .map(
                                  (o) => DropdownMenuItem(
                                    value: o['key'],
                                    child: Text(o['label']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _contexteKey = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Domaine 1 : Inattention ──
                      _domainSection(
                        t,
                        questions,
                        t.domainInattention,
                        Colors.blue.shade600,
                        1,
                        9,
                      ),
                      const SizedBox(height: 12),

                      // ── Domaine 2 : Hyperactivité ──
                      _domainSection(
                        t,
                        questions,
                        t.domainHyperactivity,
                        Colors.orange.shade700,
                        10,
                        18,
                      ),
                      const SizedBox(height: 12),

                      // ── Domaine 3 : Autorégulation ──
                      _domainSection(
                        t,
                        questions,
                        t.domainSocial,
                        Colors.purple.shade600,
                        19,
                        24,
                      ),
                      const SizedBox(height: 16),

                      // ── Notes ──
                      _sectionCard(
                        icon: Icons.notes_outlined,
                        title: t.notesOptional,
                        child: TextField(
                          controller: _noteController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: t.addNote,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),

              // ── Bouton soumettre ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      t.save,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _submit(t, questions),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _progressBar(List<Map<String, dynamic>> questions) {
    final answered = answers.length;
    final total = questions.length;
    final pct = total > 0 ? answered / total : 0.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$answered / $total',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.orange.shade50,
              color: Colors.orange,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _domainSection(
    AppLocalizations t,
    List<Map<String, dynamic>> questions,
    String domainLabel,
    Color color,
    int from,
    int to,
  ) {
    final domainQs = questions.where((q) {
      final o = q['order_index'] as int? ?? 0;
      return o >= from && o <= to;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête domaine
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.category_outlined, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  domainLabel,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Questions
        ...domainQs.map((q) {
          final order = q['order_index'] as int? ?? 0;
          final text = _questionText(t, q);
          final selected = answers[order];
          final answered = selected != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: answered ? color.withOpacity(0.4) : Colors.grey.shade200,
                width: answered ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: answered ? color : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$order',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: answered ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    children: [
                      _choiceBtn(order, 0, t.never, '0', selected, color),
                      const SizedBox(width: 6),
                      _choiceBtn(order, 1, t.sometimes, '1', selected, color),
                      const SizedBox(width: 6),
                      _choiceBtn(order, 2, t.often, '2', selected, color),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _choiceBtn(
    int key,
    int value,
    String label,
    String score,
    int? selected,
    Color color,
  ) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => answers[key] = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(AppLocalizations t, String fullName, Child child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.orange.shade100,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (child.childCode != null && child.childCode!.isNotEmpty)
                  Text(
                    child.childCode!,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                Text(
                  '$_dateObservation  •  ${child.gender == 'girl' ? t.girl : t.boy}',
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
