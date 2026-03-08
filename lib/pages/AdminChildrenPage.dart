// ============================================================
// AdminChildrenPage.dart — lib/pages/AdminChildrenPage.dart
// Multi-école : filtre par école + vue toutes écoles
// ============================================================

import 'package:flutter/material.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../services/export_service.dart';

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
  bool _exporting = false;
  String _exportMsg = '';
  String _search = '';

  // ✅ École sélectionnée (null = toutes)
  Map<String, String>? _selectedSchool;
  List<Map<String, String>> _managedSchools = [];

  @override
  void initState() {
    super.initState();
    _managedSchools = widget.admin.allManagedSchools;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DBService.getAllChildrenForAdmin(
      admin: widget.admin,
      filterSchoolName: _selectedSchool?['name'],
      filterSchoolCity: _selectedSchool?['city'],
    );
    if (mounted) {
      setState(() {
        _all = data;
        _filtered = data;
        _loading = false;
      });
    }
  }

  // ── Changer l'école filtrée ──────────────────────────────
  void _selectSchool(Map<String, String>? school) {
    setState(() => _selectedSchool = school);
    _load();
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportMsg = 'Chargement...';
    });

    final result = await ExportService.exportChildren(
      admin: widget.admin,
      onProgress: (msg) {
        if (mounted) setState(() => _exportMsg = msg);
      },
      // ✅ Passer le filtre école actuel (null = toutes les écoles)
      filterSchoolName: _selectedSchool?['name'],
      filterSchoolCity: _selectedSchool?['city'],
    );

    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportMsg = '';
    });

    if (result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun élève à exporter'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${result.errorMsg}'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result.count} élèves exportés'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
          final school = '${c['_school_name'] ?? ''} ${c['_school_city'] ?? ''}'
              .toLowerCase();
          return name.contains(lower) ||
              prof.contains(lower) ||
              school.contains(lower);
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

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final schoolLabel = _selectedSchool != null
        ? '${_selectedSchool!['name']} — ${_selectedSchool!['city']}'
        : 'Tous les élèves';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E8),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schoolLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
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
        actions: [
          _exporting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: _export,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade800.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Exporter',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // ── Barre export en cours ──
          if (_exporting)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.orange,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _exportMsg,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ Filtre par école (si multi-école)
          if (_managedSchools.length > 1) _buildSchoolFilter(),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : Column(
                    children: [
                      // ── Barre de recherche ──
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          onChanged: _filter,
                          decoration: InputDecoration(
                            hintText: 'Rechercher élève, prof, école...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.orange,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      // ── Stats rapides ──
                      if (!_loading && _all.isNotEmpty) _buildQuickStats(),
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
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  20,
                                ),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => _card(_filtered[i]),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Filtre écoles (chips horizontaux) ────────────────────
  Widget _buildSchoolFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // "Toutes"
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _selectSchool(null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedSchool == null
                        ? Colors.orange
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedSchool == null
                          ? Colors.orange
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'Toutes (${_managedSchools.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _selectedSchool == null
                          ? Colors.white
                          : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
            // Une chip par école
            ..._managedSchools.map((school) {
              final isSelected =
                  _selectedSchool?['name'] == school['name'] &&
                  _selectedSchool?['city'] == school['city'];
              final isPrimary =
                  school['name'] ==
                      widget.admin.schoolName.trim().toLowerCase() &&
                  school['city'] ==
                      widget.admin.schoolCity.trim().toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _selectSchool(school),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF5D4037)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF5D4037)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrimary ? Icons.star : Icons.school,
                          size: 10,
                          color: isSelected ? Colors.white : Colors.brown,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${school['name']} · ${school['city']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Stats rapides (risques) ──────────────────────────────
  Widget _buildQuickStats() {
    int green = 0, orange = 0, red = 0, none = 0;
    for (final c in _all) {
      switch (c['latest_overall_risk_level']) {
        case 'green':
          green++;
          break;
        case 'orange':
          orange++;
          break;
        case 'red':
          red++;
          break;
        default:
          none++;
          break;
      }
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('🟢', green, 'Faible'),
          _statChip('🟠', orange, 'Moyen'),
          _statChip('🔴', red, 'Élevé'),
          _statChip('⚪', none, 'N/A'),
        ],
      ),
    );
  }

  Widget _statChip(String emoji, int count, String label) {
    return Column(
      children: [
        Text(
          '$emoji $count',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black45),
        ),
      ],
    );
  }

  // ── Carte élève ──────────────────────────────────────────
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

    // ✅ Nom de l'école (pour mode "toutes les écoles")
    final schoolName = c['_school_name'] as String?;
    final showSchool = _selectedSchool == null && _managedSchools.length > 1;

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
            // ✅ Afficher l'école si mode "toutes"
            if (showSchool && schoolName != null)
              Text(
                '🏫 $schoolName',
                style: TextStyle(fontSize: 10, color: Colors.orange.shade700),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      ),
    );
  }

  // ── Détail élève ─────────────────────────────────────────
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
    final schoolName = c['_school_name'] as String? ?? '';
    final schoolCity = c['_school_city'] as String? ?? '';

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
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
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
            _row(Icons.class_, 'Classe', cls),
            _row(Icons.school, 'Niveau', lvl),
            _row(Icons.person, 'Professeur', prof),
            _row(Icons.qr_code, 'Code', code),
            _row(Icons.circle_outlined, 'Risque', riskLabel),
            if (schoolName.isNotEmpty)
              _row(Icons.business, 'École', '$schoolName — $schoolCity'),
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
