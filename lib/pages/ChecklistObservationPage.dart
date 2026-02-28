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

  // ✅ _save reçoit context comme paramètre → AppLocalizations disponible
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
    // ✅ t déclaré ici — dans build() → toujours valide
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text(t.newObservation),
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

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: contextCtrl,
                      decoration: InputDecoration(
                        labelText: t.contextOptional,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: t.notesOptional,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ...questions.map((q) {
                      final id = q['id'] as int;
                      final order = q['order_index']?.toString() ?? '';
                      final textFr = q['text_fr']?.toString() ?? '';
                      final selected = answers[id];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item $order',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(textFr),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _choice(id, 0, '0\n${t.never}', selected),
                                const SizedBox(width: 8),
                                _choice(id, 1, '1\n${t.sometimes}', selected),
                                const SizedBox(width: 8),
                                _choice(id, 2, '2\n${t.often}', selected),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    // ✅ passer context explicitement à _save
                    onPressed: () => _save(context, questions),
                    child: Text(t.save),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _choice(int qId, int value, String label, int? selected) {
    final isSelected = selected == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => answers[qId] = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.orange.withOpacity(0.2)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.orange : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
