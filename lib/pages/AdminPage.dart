import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../services/firestore_service.dart';

// ═══════════════════════════════════════════════════════════
// AdminPage — synchronisée avec Firestore en temps réel
//
// Architecture :
//   • Lecture  : Stream Firestore → temps réel
//   • Écriture : Firestore d'abord, puis SQLite (synced=1)
//   • Offline  : fallback sur SQLite local
// ═══════════════════════════════════════════════════════════
class AdminPage extends StatefulWidget {
  final Teacher admin;
  const AdminPage({super.key, required this.admin});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _search = '';

  // ── Écriture Firestore + SQLite ──────────────────────────

  Future<void> _firestoreUpdate(
    int teacherId,
    Map<String, dynamic> data,
  ) async {
    final docId = 'teacher_$teacherId';
    // 1. Firestore d'abord
    await FirebaseFirestore.instance.collection('teachers').doc(docId).set({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // 2. SQLite ensuite (synced=1 car déjà dans Firestore)
    await DBService.updateTeacher(
      teacherId: teacherId,
      data: {...data, 'synced': 1},
    );
  }

  // ── Activer / Désactiver ─────────────────────────────────
  Future<void> _toggleActive(Map<String, dynamic> teacher) async {
    final id = teacher['local_id'] as int? ?? teacher['id'] as int;
    final active = (teacher['is_active'] as int? ?? 1) == 1;
    await _firestoreUpdate(id, {'is_active': active ? 0 : 1});
  }

  // ── Archiver ────────────────────────────────────────────
  Future<void> _archiveTeacher(Map<String, dynamic> teacher) async {
    final t = AppLocalizations.of(context)!;
    final id = teacher['local_id'] as int? ?? teacher['id'] as int;
    final name = '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
        .trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.archiveTeacher),
        content: Text('Archiver $name ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.no),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.yes, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await _firestoreUpdate(id, {'deleted': 1});
  }

  // ── Supprimer définitivement ─────────────────────────────
  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final t = AppLocalizations.of(context)!;
    final id = teacher['local_id'] as int? ?? teacher['id'] as int;
    final name = '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'
        .trim();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Supprimer', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supprimer $name définitivement ?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Cette action est irréversible.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.white,
              size: 18,
            ),
            label: Text(t.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      // Supprimer de Firestore
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc('teacher_$id')
          .delete();
      // Supprimer de SQLite
      await DBService.deleteTeacher(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name supprimé ✅'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Ajouter / Modifier ───────────────────────────────────
  Future<void> _openTeacherForm({Map<String, dynamic>? teacher}) async {
    final t = AppLocalizations.of(context)!;
    final isEdit = teacher != null;
    final fnCtrl = TextEditingController(text: teacher?['first_name'] ?? '');
    final lnCtrl = TextEditingController(text: teacher?['last_name'] ?? '');
    final emailCtrl = TextEditingController(text: teacher?['email'] ?? '');
    final phoneCtrl = TextEditingController(
      text: teacher?['phone_number'] ?? '',
    );
    final expCtrl = TextEditingController(
      text: teacher?['years_of_experience']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit : Icons.person_add, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              isEdit ? t.edit : t.addTeacher,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(fnCtrl, t.firstName, Icons.person),
              _field(lnCtrl, t.lastName, Icons.person_outline),
              _field(
                emailCtrl,
                t.email,
                Icons.email,
                type: TextInputType.emailAddress,
                enabled: !isEdit,
              ),
              _field(
                phoneCtrl,
                t.phone,
                Icons.phone,
                type: TextInputType.phone,
              ),
              _field(
                expCtrl,
                t.yearsExperience,
                Icons.workspace_premium,
                type: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              if (fnCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(t.fillAllFields)));
                return;
              }
              if (isEdit) {
                final id = teacher['local_id'] as int? ?? teacher['id'] as int;
                await _firestoreUpdate(id, {
                  'first_name': fnCtrl.text.trim(),
                  'last_name': lnCtrl.text.trim(),
                  'phone_number': phoneCtrl.text.trim(),
                  'years_of_experience': int.tryParse(expCtrl.text.trim()) ?? 0,
                });
              } else {
                final newT = Teacher(
                  id: null,
                  firstName: fnCtrl.text.trim(),
                  lastName: lnCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  schoolName: widget.admin.schoolName,
                  schoolCity: widget.admin.schoolCity,
                  schoolRegion: widget.admin.schoolRegion,
                  role: 'teacher',
                  preferredLanguage: 'fr',
                  yearsOfExperience: int.tryParse(expCtrl.text.trim()) ?? 0,
                  gradeLevel: null,
                  passwordHash: 'kindi2025',
                  isActive: 1,
                  synced: 0,
                  deleted: 0,
                  createdAt: DateTime.now().toIso8601String(),
                  updatedAt: DateTime.now().toIso8601String(),
                );
                final ok = await DBService.insertTeacher(newT);
                if (!ok) {
                  if (ctx.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(t.emailAlreadyUsed)));
                  return;
                }
                // Sync vers Firestore immédiatement
                final saved = await DBService.getTeacherByEmail(newT.email);
                if (saved != null) await FirestoreService.upsertTeacher(saved);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              isEdit ? t.save : t.add,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _migrateSchoolKeys(); // migration one-time pour les docs existants
  }

  // Ajouter school_key aux docs Firestore qui n'en ont pas encore
  // Migration globale : normalise TOUS les docs teachers sans filtre de casse
  // Récupère tous les docs → compare school_name/city normalisés → corrige
  Future<void> _migrateSchoolKeys() async {
    try {
      final adminSchoolNorm = widget.admin.schoolName.trim().toLowerCase();
      final adminCityNorm = widget.admin.schoolCity.trim().toLowerCase();
      final targetKey = adminSchoolNorm + '__' + adminCityNorm;

      // Récupérer TOUS les teachers sans filtre pour trouver ceux à migrer
      final snap = await FirebaseFirestore.instance
          .collection('teachers')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final rawName = (data['school_name'] as String? ?? '')
            .trim()
            .toLowerCase();
        final rawCity = (data['school_city'] as String? ?? '')
            .trim()
            .toLowerCase();
        final rawKey = data['school_key'] as String?;
        final docKey = rawName + '__' + rawCity;

        // Corriger si : même école (normalisée) OU school_key manquant
        final sameSchool =
            rawName == adminSchoolNorm && rawCity == adminCityNorm;
        final needsKey = rawKey == null || rawKey.isEmpty;
        final wrongKey = rawKey != docKey; // school_key ne correspond pas

        if (sameSchool && (needsKey || wrongKey)) {
          batch.update(doc.reference, {
            'school_name': adminSchoolNorm,
            'school_city': adminCityNorm,
            'school_key': targetKey,
          });
          count++;
        }
      }

      if (count > 0) {
        await batch.commit();
        print('✅ Migration: ' + count.toString() + ' docs corrigés');
      }
    } catch (e) {
      print('ℹ️ Migration silencieuse: ' + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E8),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          t.addTeacher,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () => _openTeacherForm(),
      ),
      // ── Stream Firestore → rebuild automatique ────────────
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.streamTeachersInSchool(widget.admin),
        builder: (context, snapshot) {
          // ── États de chargement / erreur ──────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          if (snapshot.hasError) {
            // Firestore inaccessible → fallback SQLite
            return _buildWithSQLite(t);
          }

          final allTeachers = snapshot.data ?? [];

          // Sync descendante : écrire les données Firestore dans SQLite
          _syncToSQLite(allTeachers);

          // Filtrer par recherche
          final teachers = _searchFilter(allTeachers);
          final total = allTeachers.length;
          final active = allTeachers.where((t) => t['is_active'] == 1).length;

          return _buildBody(t, teachers, total, active);
        },
      ),
    );
  }

  // ── Fallback SQLite si Firestore offline ─────────────────
  Widget _buildWithSQLite(AppLocalizations t) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBService.getTeachersBySchool(
        schoolName: widget.admin.schoolName!,
        schoolCity: widget.admin.schoolCity!,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        }
        final teachers = _searchFilter(snap.data ?? []);
        final total = snap.data?.length ?? 0;
        final active = snap.data?.where((t) => t['is_active'] == 1).length ?? 0;
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Mode hors ligne — données locales',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(t, teachers, total, active)),
          ],
        );
      },
    );
  }

  // ── Sync Firestore → SQLite en arrière-plan ──────────────
  void _syncToSQLite(List<Map<String, dynamic>> firestoreTeachers) {
    for (final t in firestoreTeachers) {
      final id = t['local_id'] as int? ?? t['id'] as int?;
      if (id == null) continue;
      // Normaliser school pour cohérence locale
      final schoolName = (t['school_name'] as String? ?? '')
          .toLowerCase()
          .trim();
      final schoolCity = (t['school_city'] as String? ?? '')
          .toLowerCase()
          .trim();
      DBService.updateTeacher(
        teacherId: id,
        data: {
          'first_name': t['first_name'] ?? '',
          'last_name': t['last_name'] ?? '',
          'email': t['email'] ?? '',
          'phone_number': t['phone_number'] ?? '',
          'role': t['role'] ?? 'teacher',
          'is_active': t['is_active'] ?? 1,
          'deleted': t['deleted'] ?? 0,
          'years_of_experience': t['years_of_experience'] ?? 0,
          'school_name': schoolName,
          'school_city': schoolCity,
          'synced': 1,
        },
      ).catchError((_) {}); // silencieux
    }
  }

  // ── Filtre recherche ─────────────────────────────────────
  List<Map<String, dynamic>> _searchFilter(List<Map<String, dynamic>> list) {
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list.where((t) {
      final name = '${t['first_name'] ?? ''} ${t['last_name'] ?? ''}'
          .toLowerCase();
      final email = (t['email'] ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  // ─────────────────────────────────────────────────────────
  // BODY
  // ─────────────────────────────────────────────────────────
  Widget _buildBody(
    AppLocalizations t,
    List<Map<String, dynamic>> teachers,
    int total,
    int active,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(t, total, active),
          const SizedBox(height: 16),
          _buildSearchBar(t),
          const SizedBox(height: 16),
          if (teachers.isEmpty)
            _buildEmpty(t)
          else
            ...teachers.map((teacher) => _buildTeacherCard(t, teacher)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────
  Widget _buildHeader(AppLocalizations t, int total, int active) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne 1 : nom école ──
          Text(
            widget.admin.schoolName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            widget.admin.schoolCity,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 12),
          // ── Stats : profs + actifs + élèves ──
          Row(
            children: [
              _statBlock(
                icon: Icons.group,
                value: '$total',
                label: 'Professeurs',
              ),
              _vDivider(),
              _statBlock(
                icon: Icons.check_circle_outline,
                value: '$active',
                label: 'Actifs',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.white24,
  );

  Widget _statBlock({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Recherche ────────────────────────────────────────────
  Widget _buildSearchBar(AppLocalizations t) {
    return TextField(
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: t.search,
        prefixIcon: const Icon(Icons.search, color: Colors.orange),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.orange.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
      ),
    );
  }

  // ── Carte professeur ─────────────────────────────────────
  Widget _buildTeacherCard(AppLocalizations t, Map<String, dynamic> teacher) {
    final id = teacher['local_id'] as int? ?? teacher['id'] as int? ?? 0;
    final fullName =
        '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim();
    final email = teacher['email'] as String? ?? '';
    final active = (teacher['is_active'] as int? ?? 1) == 1;
    final role = teacher['role'] as String? ?? 'teacher';
    final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final isAdmin = role == 'admin' || role == 'super_admin';

    return FutureBuilder<Map<String, dynamic>>(
      future: DBService.getTeacherStats(id),
      builder: (ctx, statsSnap) {
        final stats = statsSnap.data ?? {'classes': 0, 'students': 0};
        final nbClass = stats['classes'] ?? 0;
        final nbEleves = stats['students'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 1,
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: active
                      ? Colors.purple.shade100
                      : Colors.grey.shade200,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.purple.shade700 : Colors.grey,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: active ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              fullName.isEmpty ? t.roleTeacher : fullName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // École + ville
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🏫 ${(teacher['school_name'] ?? '').toString()} — ${(teacher['school_city'] ?? '').toString()}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Badge admin
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role == 'super_admin' ? '👑 Super' : '🔑 Admin',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    // Stats classes / élèves
                    Text(
                      '📚 $nbClass  👦 $nbEleves',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.black45,
                size: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (v) {
                if (v == 'edit') _openTeacherForm(teacher: teacher);
                if (v == 'toggle') _toggleActive(teacher);
                if (v == 'archive') _archiveTeacher(teacher);
                if (v == 'delete') _deleteTeacher(teacher);
              },
              itemBuilder: (_) => [
                _menuItem('edit', t.edit, Icons.edit, Colors.blue),
                _menuItem(
                  'toggle',
                  active ? t.deactivate : t.activate,
                  Icons.toggle_on,
                  Colors.orange,
                ),
                _menuItem(
                  'archive',
                  t.archiveTeacher,
                  Icons.archive,
                  Colors.grey,
                ),
                const PopupMenuDivider(),
                _menuItem(
                  'delete',
                  t.delete,
                  Icons.delete_forever,
                  Colors.red,
                  textColor: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    String label,
    IconData icon,
    Color color, {
    Color? textColor,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: textColor ?? Colors.black87, fontSize: 13),
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
            Icon(Icons.people_outline, size: 64, color: Colors.purple.shade100),
            const SizedBox(height: 16),
            Text(
              t.noTeachers,
              style: const TextStyle(fontSize: 15, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.orange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: !enabled,
          fillColor: enabled ? null : Colors.grey.shade100,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PAGE 2 : Classes du professeur
// ═══════════════════════════════════════════════════════════
class AdminTeacherClassesPage extends StatefulWidget {
  final Teacher admin;
  final Map<String, dynamic> teacher;
  const AdminTeacherClassesPage({
    super.key,
    required this.admin,
    required this.teacher,
  });

  @override
  State<AdminTeacherClassesPage> createState() =>
      _AdminTeacherClassesPageState();
}

class _AdminTeacherClassesPageState extends State<AdminTeacherClassesPage> {
  late Future<List<Map<String, dynamic>>> futureClasses;

  @override
  void initState() {
    super.initState();
    futureClasses = DBService.getClassesByTeacherInSchool(
      teacherId: widget.teacher['id'] as int,
      schoolName: widget.admin.schoolName!,
      schoolCity: widget.admin.schoolCity!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final fullName =
        '${widget.teacher['first_name']} ${widget.teacher['last_name'] ?? ''}'
            .trim();
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E8),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('$fullName — ${t.myClasses}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureClasses,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          final classes = snap.data ?? [];
          if (classes.isEmpty) return Center(child: Text(t.noClasses));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: classes.length,
            itemBuilder: (context, i) {
              final c = classes[i];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.class_, color: Colors.orange),
                  title: Text(c['name'] ?? t.myClasses),
                  subtitle: Text('${t.level} : ${c['level'] ?? '-'}'),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.orange,
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminClassStudentsPage(
                        admin: widget.admin,
                        classData: c,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// PAGE 3 : Élèves d'une classe
// ═══════════════════════════════════════════════════════════
class AdminClassStudentsPage extends StatefulWidget {
  final Teacher admin;
  final Map<String, dynamic> classData;
  const AdminClassStudentsPage({
    super.key,
    required this.admin,
    required this.classData,
  });

  @override
  State<AdminClassStudentsPage> createState() => _AdminClassStudentsPageState();
}

class _AdminClassStudentsPageState extends State<AdminClassStudentsPage> {
  late Future<List<Map<String, dynamic>>> futureStudents;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    futureStudents = DBService.getStudentsByClassInSchool(
      classId: widget.classData['id'] as int,
      schoolName: widget.admin.schoolName!,
      schoolCity: widget.admin.schoolCity!,
    );
    setState(() {});
  }

  Future<void> _deleteStudent(Map<String, dynamic> s) async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Supprimer', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(
          'Supprimer ${s['first_name'] ?? ''} définitivement ?',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Supprimer Firestore + SQLite
      await FirebaseFirestore.instance
          .collection('children')
          .doc('child_${s['id']}')
          .delete();
      await DBService.deleteStudent(s['id'] as int);
      _refresh();
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
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0E8),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('${t.students} — ${widget.classData['name'] ?? ''}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureStudents,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          final students = snap.data ?? [];
          if (students.isEmpty) return Center(child: Text(t.noStudents));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, i) {
              final s = students[i];
              final fullName =
                  '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
              final risk = s['latest_overall_risk_level'] as String?;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: _riskColor(risk).withOpacity(0.15),
                    child: Icon(
                      s['gender'] == 'girl' ? Icons.face_3 : Icons.face,
                      color: _riskColor(risk),
                    ),
                  ),
                  title: Text(
                    fullName.isEmpty ? t.students : fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Code: ${s['child_code'] ?? '-'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteStudent(s),
                    tooltip: t.delete,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
