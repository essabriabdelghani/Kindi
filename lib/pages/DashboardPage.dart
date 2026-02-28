import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../services/sync_down_service.dart';
import 'EtudiantsClassePage.dart';

class DashboardPage extends StatefulWidget {
  final Teacher user;
  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _classStats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    // Sync descendante avant affichage
    await SyncDownService.syncForTeacher(
      teacherId: widget.user.id!,
      schoolName: widget.user.schoolName,
      schoolCity: widget.user.schoolCity,
    );
    final stats = await DBService.getDashboardStats(widget.user.id!);
    if (mounted)
      setState(() {
        _classStats = stats;
        _loading = false;
      });
  }

  // ─── Couleur selon le level ───
  Color _levelColor(String level) {
    final l = level.toLowerCase();
    if (l.contains('grande') || l.contains('gs'))
      return const Color(0xFF2E7D32);
    if (l.contains('moyen') || l.contains('ms')) return const Color(0xFFE65100);
    if (l.contains('petite') || l.contains('ps'))
      return const Color(0xFF1565C0);
    return const Color(0xFF6A1B9A);
  }

  IconData _levelIcon(String level) {
    final l = level.toLowerCase();
    if (l.contains('grande') || l.contains('gs')) return Icons.school;
    if (l.contains('moyen') || l.contains('ms')) return Icons.menu_book;
    if (l.contains('petite') || l.contains('ps')) return Icons.child_care;
    return Icons.class_;
  }

  // ─── Totaux globaux ───
  int get _totalStudents =>
      _classStats.fold(0, (s, c) => s + (c['total'] as int));
  int get _totalGreen => _classStats.fold(0, (s, c) => s + (c['green'] as int));
  int get _totalOrange =>
      _classStats.fold(0, (s, c) => s + (c['orange'] as int));
  int get _totalRed => _classStats.fold(0, (s, c) => s + (c['red'] as int));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 900 ? 880.0 : width * 0.96;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E8),
      body: RefreshIndicator(
        color: Colors.orange,
        onRefresh: _loadData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.orange),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: maxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Salutation ───
                        _buildHeader(t),
                        const SizedBox(height: 24),

                        // ─── Cartes résumé global ───
                        _buildGlobalSummary(t),
                        const SizedBox(height: 28),

                        // ─── Titre section classes ───
                        Text(
                          t.myClasses,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ─── Pas de classes ───
                        if (_classStats.isEmpty)
                          _buildEmpty(t)
                        else
                          ..._classStats.map((cls) => _buildClassCard(t, cls)),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Header
  // ══════════════════════════════════════════
  Widget _buildHeader(AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6F00), Color(0xFFFF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.25),
            child: Text(
              widget.user.firstName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.welcome} 👋',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '${widget.user.firstName} ${widget.user.lastName ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.user.schoolName,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$_totalStudents',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                t.students,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  // Résumé global
  // ══════════════════════════════════════════
  Widget _buildGlobalSummary(AppLocalizations t) {
    return Row(
      children: [
        _summaryChip(
          label: t.riskGreen,
          count: _totalGreen,
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle,
        ),
        const SizedBox(width: 10),
        _summaryChip(
          label: t.riskOrange,
          count: _totalOrange,
          color: const Color(0xFFE65100),
          icon: Icons.warning_amber,
        ),
        const SizedBox(width: 10),
        _summaryChip(
          label: t.riskRed,
          count: _totalRed,
          color: const Color(0xFFC62828),
          icon: Icons.error,
        ),
      ],
    );
  }

  Widget _summaryChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // Carte par classe
  // ══════════════════════════════════════════
  Widget _buildClassCard(AppLocalizations t, Map<String, dynamic> cls) {
    final color = _levelColor(cls['level'] as String? ?? cls['name'] as String);
    final icon = _levelIcon(cls['level'] as String? ?? cls['name'] as String);
    final total = cls['total'] as int;
    final green = cls['green'] as int;
    final orange = cls['orange'] as int;
    final red = cls['red'] as int;
    final recent = (cls['recent'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final name = cls['name'] as String;
    final level = cls['level'] as String? ?? '';
    final year = cls['academic_year'] as String? ?? '';
    final classId = cls['id'] as int;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EtudiantsClassePage(
            classId: classId,
            className: name,
            mainTeacherId: widget.user.id!,
          ),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── En-tête de la carte ───
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.75)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (level.isNotEmpty)
                          Text(
                            '${t.level} : $level',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        if (year.isNotEmpty)
                          Text(
                            year,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ─── Badge total ───
                  Column(
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      Text(
                        t.students,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Barre de risque ───
            if (total > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.riskLevel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildRiskBar(green, orange, red, total),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _riskDot(Colors.green, '$green ${t.riskGreen}'),
                        const SizedBox(width: 12),
                        _riskDot(Colors.orange, '$orange ${t.riskOrange}'),
                        const SizedBox(width: 12),
                        _riskDot(Colors.red, '$red ${t.riskRed}'),
                      ],
                    ),
                  ],
                ),
              ),

            // ─── Élèves récents ───
            if (recent.isNotEmpty) ...[
              const Divider(height: 24, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${t.students} (${t.active})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...recent.map((s) => _recentStudentRow(t, s)),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 14),

            // ─── Bouton voir tous ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EtudiantsClassePage(
                        classId: classId,
                        className: name,
                        mainTeacherId: widget.user.id!,
                      ),
                    ),
                  ).then((_) => _loadData()),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(
                    '${t.students} ($total)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barre de risque proportionnelle ──
  Widget _buildRiskBar(int green, int orange, int red, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (green > 0)
              Expanded(
                flex: green,
                child: Container(color: Colors.green),
              ),
            if (orange > 0)
              Expanded(
                flex: orange,
                child: Container(color: Colors.orange),
              ),
            if (red > 0)
              Expanded(
                flex: red,
                child: Container(color: Colors.red),
              ),
            if (green + orange + red < total)
              Expanded(
                flex: total - green - orange - red,
                child: Container(color: Colors.grey.shade300),
              ),
          ],
        ),
      ),
    );
  }

  Widget _riskDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
        ),
      ],
    );
  }

  Widget _recentStudentRow(AppLocalizations t, Map<String, dynamic> s) {
    final risk = s['latest_overall_risk_level'] as String?;
    final Color riskColor;
    switch (risk) {
      case 'green':
        riskColor = Colors.green;
        break;
      case 'orange':
        riskColor = Colors.orange;
        break;
      case 'red':
        riskColor = Colors.red;
        break;
      default:
        riskColor = Colors.grey;
    }
    final name = '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            s['gender'] == 'girl' ? Icons.face_3 : Icons.face,
            size: 16,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name.isEmpty ? t.students : name,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.class_outlined, size: 70, color: Colors.orange.shade200),
            const SizedBox(height: 16),
            Text(
              t.noClasses,
              style: const TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
            ),
            const SizedBox(height: 6),
            Text(
              t.noClassesHint,
              style: const TextStyle(fontSize: 13, color: Color(0xFFBDBDBD)),
            ),
          ],
        ),
      ),
    );
  }
}
