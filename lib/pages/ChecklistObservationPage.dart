import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/db_service.dart';

class NouvelleObservationChecklistPage extends StatefulWidget {
  final int childId;
  final int teacherId;
  final int classId;

  const NouvelleObservationChecklistPage({
    super.key,
    required this.childId,
    required this.teacherId,
    required this.classId,
  });

  @override
  State<NouvelleObservationChecklistPage> createState() =>
      _NouvelleObservationChecklistPageState();
}

class _NouvelleObservationChecklistPageState
    extends State<NouvelleObservationChecklistPage> {
  late Future<List<Map<String, dynamic>>> futureQuestions;
  final Map<int, int> answers = {};
  final TextEditingController contextCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    futureQuestions = DBService.getChecklistQuestions();
  }

  @override
  void dispose() {
    contextCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  // Récupère le texte de la question selon la langue active
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

  // Domaine traduit selon order_index
  String _domainLabel(AppLocalizations t, int order) {
    if (order <= 9) return t.domainInattention;
    if (order <= 18) return t.domainHyperactivity;
    return t.domainSocial;
  }

  Color _domainColor(int order) {
    if (order <= 9) return Colors.blue.shade600;
    if (order <= 18) return Colors.orange.shade700;
    return Colors.purple.shade600;
  }

  Future<void> _save(
    BuildContext context,
    List<Map<String, dynamic>> questions,
  ) async {
    final t = AppLocalizations.of(context)!;
    for (final q in questions) {
      final id = q['id'] as int;
      if (!answers.containsKey(id)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.answerAllQuestions)));
        return;
      }
    }
    await DBService.insertObservationChecklist(
      childId: widget.childId,
      teacherId: widget.teacherId,
      classId: widget.classId,
      context: contextCtrl.text.trim(),
      notes: notesCtrl.text.trim(),
      answers: answers,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t.observationSaved)));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

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
        future: futureQuestions,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          final questions = snap.data ?? [];
          if (questions.isEmpty) {
            return Center(child: Text(t.noData));
          }

          // Grouper les questions par domaine
          final domains = [
            {
              'label': t.domainInattention,
              'color': Colors.blue.shade600,
              'range': [1, 9],
            },
            {
              'label': t.domainHyperactivity,
              'color': Colors.orange.shade700,
              'range': [10, 18],
            },
            {
              'label': t.domainSocial,
              'color': Colors.purple.shade600,
              'range': [19, 24],
            },
          ];

          return Column(
            children: [
              // Barre de progression
              _progressBar(questions),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    // Contexte + notes
                    _fieldCard(
                      child: Column(
                        children: [
                          TextField(
                            controller: contextCtrl,
                            decoration: InputDecoration(
                              labelText: t.contextOptional,
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                color: Colors.orange,
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: notesCtrl,
                            minLines: 2,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: t.notesOptional,
                              prefixIcon: const Icon(
                                Icons.notes_outlined,
                                color: Colors.orange,
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.orange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Questions par domaine
                    for (final domain in domains) ...[
                      _domainHeader(
                        label: domain['label'] as String,
                        color: domain['color'] as Color,
                      ),
                      ...questions
                          .where((q) {
                            final o = q['order_index'] as int? ?? 0;
                            final r = domain['range'] as List;
                            return o >= r[0] && o <= r[1];
                          })
                          .map((q) => _questionCard(t, q)),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),

              // Bouton sauvegarder
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                  height: 50,
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
                    onPressed: () => _save(context, questions),
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
                '$answered / $total répondues',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                '${(pct * 100).toInt()}%',
                style: TextStyle(
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

  Widget _domainHeader({required String label, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _questionCard(AppLocalizations t, Map<String, dynamic> q) {
    final id = q['id'] as int;
    final order = q['order_index'] as int? ?? 0;
    final text = _questionText(t, q);
    final selected = answers[id];
    final answered = selected != null;
    final color = _domainColor(order);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: answered ? color.withOpacity(0.4) : Colors.grey.shade200,
          width: answered ? 1.5 : 1,
        ),
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
          // En-tête question
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

          // Boutons de réponse
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _choiceBtn(id, 0, t.never, '0', selected, color),
                const SizedBox(width: 6),
                _choiceBtn(id, 1, t.sometimes, '1', selected, color),
                const SizedBox(width: 6),
                _choiceBtn(id, 2, t.often, '2', selected, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceBtn(
    int qId,
    int value,
    String label,
    String score,
    int? selected,
    Color color,
  ) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => answers[qId] = value),
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
}
