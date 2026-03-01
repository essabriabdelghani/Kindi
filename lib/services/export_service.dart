import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/db_service.dart';
import '../models/teachers.dart';

// ═══════════════════════════════════════════════════════════
// Abréviations des 24 questions pour les en-têtes Excel
// ═══════════════════════════════════════════════════════════
const List<Map<String, String>> _questionAbbr = [
  // INATTENTION (Q1–Q9)
  {
    'id': '1',
    'abbr': 'INAT1-Concentr.',
    'full': 'Difficulte a rester concentre',
  },
  {
    'id': '2',
    'abbr': 'INAT2-Distrait.',
    'full': 'Facilement distrait (bruits/mvmt)',
  },
  {'id': '3', 'abbr': 'INAT3-Fin.Tâche', 'full': 'Mal a terminer les taches'},
  {
    'id': '4',
    'abbr': 'INAT4-Oubli.Cons.',
    'full': 'Oublie facilement les consignes',
  },
  {
    'id': '5',
    'abbr': 'INAT5-Consig.Multi',
    'full': 'Mal avec consignes multi-etapes',
  },
  {
    'id': '6',
    'abbr': 'INAT6-Evit.Attn',
    'full': 'Evite taches attention soutenue',
  },
  {
    'id': '7',
    'abbr': 'INAT7-Err.Inat.',
    'full': 'Erreurs d\'inattention simples',
  },
  {'id': '8', 'abbr': 'INAT8-Organ.', 'full': 'Difficultes a s-organiser'},
  {'id': '9', 'abbr': 'INAT9-Perd.Obj.', 'full': 'Perd souvent ses affaires'},
  // HYPERACTIVITÉ/IMPULSIVITÉ (Q10–Q18)
  {'id': '10', 'abbr': 'HYP10-Assis.', 'full': 'Mal a rester assis'},
  {
    'id': '11',
    'abbr': 'HYP11-Bouge.',
    'full': 'Bouge excessivement (court/grimpe)',
  },
  {'id': '12', 'abbr': 'HYP12-Agite.', 'full': 'S\'agite (mains/pieds/corps)'},
  {'id': '13', 'abbr': 'HYP13-Parle.', 'full': 'Parle excessivement'},
  {'id': '14', 'abbr': 'HYP14-Interr.', 'full': 'Interrompt frequemment'},
  {'id': '15', 'abbr': 'HYP15-Tour.', 'full': 'Mal a attendre son tour'},
  {'id': '16', 'abbr': 'HYP16-Impuls.', 'full': 'Agit sans reflechir'},
  {
    'id': '17',
    'abbr': 'HYP17-Rep.Vite.',
    'full': 'Repond avant fin de question',
  },
  {
    'id': '18',
    'abbr': 'HYP18-Quitte.',
    'full': 'Quitte sa place sans permission',
  },
  // AUTORÉGULATION/SOCIAL (Q19–Q24)
  {'id': '19', 'abbr': 'SOC19-Emot.', 'full': 'Mal a gerer ses emotions'},
  {'id': '20', 'abbr': 'SOC20-Routine.', 'full': 'S-enerve si routine change'},
  {'id': '21', 'abbr': 'SOC21-Calme.', 'full': 'Mal a se calmer apres conflit'},
  {
    'id': '22',
    'abbr': 'SOC22-Partage.',
    'full': 'Mal a partager/jouer cooper.',
  },
  {
    'id': '23',
    'abbr': 'SOC23-Phys.Imp.',
    'full': 'Comportements physiques impulsifs',
  },
  {
    'id': '24',
    'abbr': 'SOC24-Règles.',
    'full': 'Besoin rappels frequents regles',
  },
];

class ExportService {
  static int? _calcAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    try {
      final dt = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - dt.year;
      if (now.month < dt.month || (now.month == dt.month && now.day < dt.day))
        age--;
      return age;
    } catch (_) {
      return null;
    }
  }

  static String _riskLabel(String? r) {
    switch (r) {
      case 'green':
        return 'Faible';
      case 'orange':
        return 'Moyen';
      case 'red':
        return 'Élevé';
      default:
        return 'Non évalué';
    }
  }

  static String _genderLabel(String? g) {
    if (g == 'girl') return 'Fille';
    if (g == 'boy') return 'Garçon';
    return '—';
  }

  // 0 = Jamais, 1 = Parfois, 2 = Souvent
  static String _answerLabel(int? v) {
    switch (v) {
      case 0:
        return 'Jamais';
      case 1:
        return 'Parfois';
      case 2:
        return 'Souvent';
      default:
        return '—';
    }
  }

  static String _csv(dynamic val) {
    if (val == null) return '';
    final s = val.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  // Charger les réponses de la dernière observation pour un enfant
  static Future<Map<int, int>> _getLatestAnswers(int childId) async {
    final db = await DBService.database;

    // Récupérer la dernière observation
    final obs = await db.query(
      'observations',
      where: 'child_id = ? AND deleted = 0',
      whereArgs: [childId],
      orderBy: 'date DESC, id DESC',
      limit: 1,
    );
    if (obs.isEmpty) return {};

    final obsId = obs.first['id'] as int;

    // Récupérer toutes les réponses de cette observation
    final answers = await db.query(
      'observation_answers',
      where: 'observation_id = ? AND deleted = 0',
      whereArgs: [obsId],
    );

    final Map<int, int> result = {};
    for (final a in answers) {
      final qId = a['question_id'] as int;
      final val = a['numeric_value'] as int? ?? 0;
      result[qId] = val;
    }
    return result;
  }

  // Charger le mapping question order_index → id depuis la DB
  static Future<Map<int, int>> _getQuestionIdMap() async {
    final db = await DBService.database;
    final rows = await db.query(
      'checklist_questions',
      columns: ['id', 'order_index'],
      where: 'deleted = 0',
      orderBy: 'order_index ASC',
    );
    final Map<int, int> map = {}; // order_index → id
    for (final r in rows) {
      map[r['order_index'] as int] = r['id'] as int;
    }
    return map;
  }

  // ── Export principal ─────────────────────────────────────
  static Future<ExportResult> exportChildren({
    required Teacher admin,
    required void Function(String msg) onProgress,
  }) async {
    try {
      onProgress('Chargement des élèves...');

      final children = await DBService.getAllChildrenWithDetails(
        schoolName: admin.schoolName!,
        schoolCity: admin.schoolCity!,
      );

      if (children.isEmpty) return ExportResult.empty;

      onProgress('Chargement du questionnaire...');
      final questionIdMap = await _getQuestionIdMap();

      // ── En-têtes ──
      final infoHeaders = [
        'Code',
        'Prénom',
        'Nom',
        'Genre',
        'Âge',
        'Naissance',
        'Classe',
        'Niveau',
        'Professeur',
        'Risque',
        'Score Inat.%',
        'Score Hyp.%',
        'Score Soc.%',
        'Score Total%',
      ];
      final questionHeaders = _questionAbbr.map((q) => q['abbr']!).toList();
      final allHeaders = [...infoHeaders, ...questionHeaders];

      final lines = StringBuffer();

      // ── Ligne 1 : en-têtes abréviés ──
      lines.writeln(allHeaders.map(_csv).join(','));

      // ── Ligne 2 : légende des abréviations ──
      // (vide pour les colonnes info, puis le texte complet pour les questions)
      final legendRow = [
        ...List.filled(infoHeaders.length, ''),
        ..._questionAbbr.map((q) => q['full']!),
      ];
      lines.writeln(legendRow.map(_csv).join(','));

      // ── Ligne 3 : valeurs possibles ──
      final valuesRow = [
        ...List.filled(infoHeaders.length, ''),
        ...List.filled(
          questionHeaders.length,
          '0=Jamais | 1=Parfois | 2=Souvent',
        ),
      ];
      lines.writeln(valuesRow.map(_csv).join(','));

      lines.writeln(''); // séparateur

      int i = 0;
      for (final c in children) {
        i++;
        onProgress('Export élève $i / ${children.length}...');

        final childId = c['id'] as int;
        final age = _calcAge(c['birth_date'] as String?);

        // Récupérer les réponses
        final answers = await _getLatestAnswers(childId);

        // Infos de base
        final infoRow = [
          c['child_code'],
          c['first_name'],
          c['last_name'],
          _genderLabel(c['gender'] as String?),
          age != null ? '$age ans' : '',
          c['birth_date'] ?? '',
          c['class_name'],
          c['class_level'],
          '${c['teacher_first_name'] ?? ''} ${c['teacher_last_name'] ?? ''}'
              .trim(),
          _riskLabel(c['latest_overall_risk_level'] as String?),
          // Scores (depuis la DB children + dernière observation)
          '', '', '', '', // placeholder — récupéré via observation scores
        ];

        // Récupérer les scores depuis la dernière observation
        final db = await DBService.database;
        final obs = await db.query(
          'observations',
          where: 'child_id = ? AND deleted = 0',
          whereArgs: [childId],
          orderBy: 'date DESC, id DESC',
          limit: 1,
        );

        String inatPct = '—', hypPct = '—', socPct = '—', totalPct = '—';
        if (obs.isNotEmpty) {
          inatPct = obs.first['inattention_percent'] != null
              ? '${(obs.first['inattention_percent'] as double).toStringAsFixed(0)}%'
              : '—';
          hypPct = obs.first['hyperactivity_percent'] != null
              ? '${(obs.first['hyperactivity_percent'] as double).toStringAsFixed(0)}%'
              : '—';
          socPct = obs.first['selfreg_social_percent'] != null
              ? '${(obs.first['selfreg_social_percent'] as double).toStringAsFixed(0)}%'
              : '—';
          totalPct = obs.first['total_percent'] != null
              ? '${(obs.first['total_percent'] as double).toStringAsFixed(0)}%'
              : '—';
        }

        final finalInfoRow = [
          c['child_code'],
          c['first_name'],
          c['last_name'],
          _genderLabel(c['gender'] as String?),
          age != null ? '$age ans' : '',
          c['birth_date'] ?? '',
          c['class_name'],
          c['class_level'],
          '${c['teacher_first_name'] ?? ''} ${c['teacher_last_name'] ?? ''}'
              .trim(),
          _riskLabel(c['latest_overall_risk_level'] as String?),
          inatPct,
          hypPct,
          socPct,
          totalPct,
        ];

        // Réponses aux 24 questions dans l'ordre
        final answerRow = _questionAbbr.map((q) {
          final orderIdx = int.parse(q['id']!);
          final qId = questionIdMap[orderIdx];
          if (qId == null) return '—';
          final val = answers[qId];
          return val != null ? _answerLabel(val) : '—';
        }).toList();

        lines.writeln([...finalInfoRow, ...answerRow].map(_csv).join(','));
      }

      onProgress('Enregistrement du fichier...');

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fileName =
          'eleves_${admin.schoolName}_${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}.csv';
      final file = File('${dir.path}/$fileName');
      // UTF-16 LE avec BOM — lu parfaitement par Google Sheets et Excel
      final utf16Bytes = _encodeUtf16Le(lines.toString());
      await file.writeAsBytes(utf16Bytes);

      onProgress('Ouverture du partage...');

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Élèves — ${admin.schoolName} (${children.length} élèves)',
        text:
            'Export du ${now.day}/${now.month}/${now.year} — ${children.length} élève${children.length > 1 ? "s" : ""}',
      );

      return ExportResult.success(children.length);
    } catch (e) {
      return ExportResult.error(e.toString());
    }
  }
}

// Encode une string en UTF-16 Little Endian avec BOM
// Google Sheets et Excel reconnaissent toujours cet encodage
List<int> _encodeUtf16Le(String s) {
  final bom = [0xFF, 0xFE]; // BOM UTF-16 LE
  final bytes = <int>[];
  for (final rune in s.runes) {
    if (rune <= 0xFFFF) {
      bytes.add(rune & 0xFF);
      bytes.add((rune >> 8) & 0xFF);
    } else {
      // Surrogate pair pour les caractères > 0xFFFF (rare)
      final u = rune - 0x10000;
      final high = 0xD800 + (u >> 10);
      final low = 0xDC00 + (u & 0x3FF);
      bytes.add(high & 0xFF);
      bytes.add((high >> 8) & 0xFF);
      bytes.add(low & 0xFF);
      bytes.add((low >> 8) & 0xFF);
    }
  }
  return [...bom, ...bytes];
}

class ExportResult {
  final bool ok;
  final int count;
  final String? errorMsg;
  final bool isEmpty;

  const ExportResult._({
    required this.ok,
    this.count = 0,
    this.errorMsg,
    this.isEmpty = false,
  });

  static const ExportResult empty = ExportResult._(ok: false, isEmpty: true);
  static ExportResult success(int n) => ExportResult._(ok: true, count: n);
  static ExportResult error(String msg) =>
      ExportResult._(ok: false, errorMsg: msg);
}
