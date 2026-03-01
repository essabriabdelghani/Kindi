import 'package:flutter/material.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../l10n/app_localizations.dart';

class AdminChildrenPage extends StatefulWidget {
  final Teacher admin;
  const AdminChildrenPage({super.key, required this.admin});

  @override
  State<AdminChildrenPage> createState() => _AdminChildrenPageState();
}

class _AdminChildrenPageState extends State<AdminChildrenPage> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DBService.getAllChildrenWithDetails(
      schoolName: widget.admin.schoolName!,
      schoolCity: widget.admin.schoolCity!,
    );
    if (mounted)
      setState(() {
        _all = data;
        _filtered = data;
        _loading = false;
      });
  }

  void _filter(String q) {
    setState(() {
      _search = q;
      if (q.isEmpty) {
        _filtered = _all;
      } else {
        final lower = q.toLowerCase();
        _filtered = _all.where((c) {
          final name = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'
              .toLowerCase();
          final prof =
              '${c['teacher_first_name'] ?? ''} ${c['teacher_last_name'] ?? ''}'
                  .toLowerCase();
          return name.contains(lower) || prof.contains(lower);
        }).toList();
      }
    });
  }

  String _age(String? bd) {
    if (bd == null || bd.isEmpty) return '—';
    try {
      final dt = DateTime.parse(bd);
      final now = DateTime.now();
      int age = now.year - dt.year;
      if (now.month < dt.month || (now.month == dt.month && now.day < dt.day))
        age--;
      return '$age ans';
    } catch (_) {
      return '—';
    }
  }

  Color _riskColor(String? r) {
    switch (r) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E8),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tous les élèves',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              _search.isEmpty
                  ? 'Total : ${_all.length} élève${_all.length > 1 ? "s" : ""}'
                  : '${_filtered.length} / ${_all.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                // ── Barre de recherche ──
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.orange,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                // ── Liste ──
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.child_care,
                                size: 60,
                                color: Colors.orange.shade100,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _search.isEmpty
                                    ? 'Aucun élève'
                                    : 'Aucun résultat',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _card(_filtered[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _card(Map<String, dynamic> c) {
    final fn = c['first_name'] as String? ?? '';
    final ln = c['last_name'] as String? ?? '';
    final name = '$fn $ln'.trim();
    final age = _age(c['birth_date'] as String?);
    final cls = c['class_name'] as String? ?? '—';
    final lvl = c['class_level'] as String? ?? '—';
    final tf = c['teacher_first_name'] as String? ?? '';
    final tl = c['teacher_last_name'] as String? ?? '';
    final prof = '$tf $tl'.trim();
    final risk = c['latest_overall_risk_level'] as String?;
    final init = fn.isNotEmpty ? fn[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => _detail(c),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Text(
            init,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name.isEmpty ? '—' : name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _riskColor(risk),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$age  •  $lvl  •  $cls',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '👤 $prof',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      ),
    );
  }

  void _detail(Map<String, dynamic> c) {
    final fn = c['first_name'] as String? ?? '';
    final ln = c['last_name'] as String? ?? '';
    final name = '$fn $ln'.trim();
    final age = _age(c['birth_date'] as String?);
    final cls = c['class_name'] as String? ?? '—';
    final lvl = c['class_level'] as String? ?? '—';
    final tf = c['teacher_first_name'] as String? ?? '';
    final tl = c['teacher_last_name'] as String? ?? '';
    final prof = '$tf $tl'.trim();
    final risk = c['latest_overall_risk_level'] as String?;
    final code = c['child_code'] as String? ?? '—';
    final gender = c['gender'] as String? ?? 'boy';

    String riskLabel;
    switch (risk) {
      case 'green':
        riskLabel = '🟢 Faible';
        break;
      case 'orange':
        riskLabel = '🟠 Moyen';
        break;
      case 'red':
        riskLabel = '🔴 Élevé';
        break;
      default:
        riskLabel = '— Non évalué';
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.orange.shade100,
              child: Text(
                fn.isNotEmpty ? fn[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name.isEmpty ? '—' : name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${gender == 'girl' ? 'Fille' : 'Garçon'}  •  $age',
              style: const TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // Détails en liste simple
            _row(Icons.class_, 'Classe', cls),
            _row(Icons.school, 'Niveau', lvl),
            _row(Icons.person, 'Professeur', prof),
            _row(Icons.qr_code, 'Code', code),
            _row(Icons.circle_outlined, 'Risque', riskLabel),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orange),
          const SizedBox(width: 12),
          Text(
            '$label : ',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
