import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/children.dart';
import '../services/db_service.dart';
import '../services/sync_engine.dart';

class FormulaireObservationPage extends StatefulWidget {
  final Child child;

  const FormulaireObservationPage({super.key, required this.child});

  @override
  State<FormulaireObservationPage> createState() =>
      _FormulaireObservationPageState();
}

class _FormulaireObservationPageState extends State<FormulaireObservationPage> {
  // ── État ───────────────────────────────────────────────
  String _context = "Regroupement";
  final _noteCtrl = TextEditingController();

  // questionId → valeur (0=Jamais, 1=Parfois, 2=Souvent)
  final Map<int, int> _answers = {};

  // Questions chargées depuis SQLite
  List<Map<String, dynamic>> _questions = [];

  bool _loading = true; // chargement questions
  bool _submitting = false; // envoi en cours

  late final String _dateObservation;

  // ── domaines lisibles ─────────────────────────────────
  final Map<String, String> _domainLabels = {
    'inattention': '🔵 Inattention',
    'hyperactivity_impulsivity': '🔴 Hyperactivité / Impulsivité',
    'self_regulation_social': '🟢 Autorégulation sociale',
  };

  @override
  void initState() {
    super.initState();
    _dateObservation = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _loadQuestions();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  // Charger les questions depuis SQLite
  // ══════════════════════════════════════════════════════
  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final qs = await DBService.getChecklistQuestions();

    // Initialiser toutes les réponses à 0 (Jamais)
    final answers = <int, int>{};
    for (final q in qs) {
      answers[q['id'] as int] = 0;
    }

    setState(() {
      _questions = qs;
      _answers.addAll(answers);
      _loading = false;
    });
  }

  // ══════════════════════════════════════════════════════
  // Soumettre → SQLite (synced=0) → SyncEngine → Firestore
  // ══════════════════════════════════════════════════════
  Future<void> _submit() async {
    if (_answers.isEmpty) return;

    setState(() => _submitting = true);

    try {
      // ✅ insertObservationChecklist avec synced=0
      await DBService.insertObservationChecklist(
        childId: widget.child.id!,
        teacherId: widget.child.mainTeacherId,
        classId: widget.child.classId,
        context: _context,
        notes: _noteCtrl.text.trim(),
        answers: _answers,
      );

      // ✅ Sync montante vers Firestore
      SyncEngine.syncAll(teacherId: widget.child.mainTeacherId);

      if (!mounted) return;
      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Observation sauvegardée ✅"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ══════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final fullName = "${child.firstName} ${child.lastName ?? ''}".trim();
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 800 ? 800.0 : width * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Nouvelle observation"),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.orange),
                  SizedBox(height: 15),
                  Text(
                    "Chargement des questions...",
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Carte enfant ───────────────────
                      _InfoCard(
                        fullName: fullName,
                        childCode: child.childCode,
                        gender: child.gender,
                        dateObservation: _dateObservation,
                      ),
                      const SizedBox(height: 20),

                      // ── Contexte ───────────────────────
                      _sectionTitle("Contexte"),
                      _contextDropdown(),
                      const SizedBox(height: 20),

                      // ── Questions groupées par domaine ─
                      ..._buildQuestionsByDomain(),
                      const SizedBox(height: 20),

                      // ── Notes ──────────────────────────
                      _sectionTitle("Notes (optionnel)"),
                      _notesField(),
                      const SizedBox(height: 30),

                      // ── Score résumé ───────────────────
                      _ScorePreview(
                        answers: _answers,
                        total: _questions.length,
                      ),
                      const SizedBox(height: 20),

                      // ── Bouton soumettre ───────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _submitting
                                ? "Envoi en cours..."
                                : "Soumettre l'observation",
                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            disabledBackgroundColor: Colors.orange.withOpacity(
                              0.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _submitting ? null : _submit,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── Questions groupées par domaine ──────────────────────
  List<Widget> _buildQuestionsByDomain() {
    // Grouper les questions par domaine
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final q in _questions) {
      final domain = q['domain'] as String? ?? 'other';
      grouped.putIfAbsent(domain, () => []);
      grouped[domain]!.add(q);
    }

    final widgets = <Widget>[];
    grouped.forEach((domain, questions) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête domaine
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Text(
                  _domainLabels[domain] ?? domain,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),

              // Questions du domaine
              ...questions.map((q) {
                final qId = q['id'] as int;
                final text =
                    q['text_fr'] as String? ?? q['text_en'] as String? ?? '';
                final val = _answers[qId] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _choiceBtn(qId, 0, val, "Jamais", Colors.green),
                        _choiceBtn(qId, 1, val, "Parfois", Colors.orange),
                        _choiceBtn(qId, 2, val, "Souvent", Colors.red),
                      ],
                    ),
                    const Divider(height: 1, indent: 14, endIndent: 14),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    });
    return widgets;
  }

  Widget _choiceBtn(int qId, int val, int current, String label, Color color) {
    final selected = current == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _answers[qId] = val),
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.15)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.grey.withOpacity(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                val == 0
                    ? Icons.check_circle_outline
                    : val == 1
                    ? Icons.access_time
                    : Icons.warning_amber_outlined,
                color: selected ? color : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ─────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
    ),
  );

  Widget _contextDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange),
    ),
    child: DropdownButton<String>(
      value: _context,
      isExpanded: true,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: "Regroupement", child: Text("Regroupement")),
        DropdownMenuItem(value: "Jeu libre", child: Text("Jeu libre")),
        DropdownMenuItem(value: "Activité", child: Text("Activité")),
        DropdownMenuItem(value: "Récréation", child: Text("Récréation")),
      ],
      onChanged: (v) => setState(() => _context = v!),
    ),
  );

  Widget _notesField() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange),
    ),
    child: TextField(
      controller: _noteCtrl,
      maxLines: 3,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(15),
        border: InputBorder.none,
        hintText: "Ajouter une note...",
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════
// Widget carte enfant
// ══════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final String fullName;
  final String? childCode;
  final String gender;
  final String dateObservation;

  const _InfoCard({
    required this.fullName,
    required this.childCode,
    required this.gender,
    required this.dateObservation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.withOpacity(0.15),
            child: Icon(
              gender == 'girl' ? Icons.face_3 : Icons.face,
              color: Colors.orange,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
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
                if (childCode != null && childCode!.isNotEmpty)
                  Text(
                    "Code : $childCode",
                    style: const TextStyle(color: Colors.black54),
                  ),
                Text(
                  "📅 $dateObservation",
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Widget score preview en temps réel
// ══════════════════════════════════════════════════════════
class _ScorePreview extends StatelessWidget {
  final Map<int, int> answers;
  final int total;

  const _ScorePreview({required this.answers, required this.total});

  @override
  Widget build(BuildContext context) {
    if (answers.isEmpty || total == 0) return const SizedBox();

    final score = answers.values.fold<int>(0, (a, b) => a + b);
    final maxScore = total * 2;
    final percent = (score / maxScore * 100).round();

    Color color;
    String label;
    if (percent < 33) {
      color = Colors.green;
      label = "🟢 Risque Faible";
    } else if (percent < 66) {
      color = Colors.orange;
      label = "🟠 Risque Modéré";
    } else {
      color = Colors.red;
      label = "🔴 Risque Élevé";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Score estimé",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(label, style: TextStyle(color: color, fontSize: 14)),
            ],
          ),
          Text(
            "$percent%",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
