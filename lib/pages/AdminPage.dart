// ============================================================
// AdminPage.dart — lib/pages/AdminPage.dart
// Multi-école : admin peut gérer plusieurs écoles
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../services/firestore_service.dart';

class AdminPage extends StatefulWidget {
  final Teacher admin;
  const AdminPage({super.key, required this.admin});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _search = '';

  // ✅ École sélectionnée pour le filtre (null = toutes)
  Map<String, String>? _selectedSchool;

  // ✅ Liste des écoles gérées (mise à jour dynamiquement)
  List<Map<String, String>> _managedSchools = [];

  @override
  void initState() {
    super.initState();
    _managedSchools = widget.admin.allManagedSchools;
    _migrateSchoolKeys();
  }

  // ── École actuellement filtrée ───────────────────────────
  String get _currentSchoolKey {
    if (_selectedSchool != null) {
      return '${_selectedSchool!['name']}__${_selectedSchool!['city']}';
    }
    // Par défaut : première école (principale)
    final schools = widget.admin.allManagedSchools;
    if (schools.isEmpty) return '';
    return '${schools.first['name']}__${schools.first['city']}';
  }

  // ── Écriture Firestore + SQLite ──────────────────────────
  Future<void> _firestoreUpdate(
    int teacherId,
    Map<String, dynamic> data,
  ) async {
    await FirebaseFirestore.instance
        .collection('teachers')
        .doc('teacher_$teacherId')
        .set({
          ...data,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    await DBService.updateTeacher(
      teacherId: teacherId,
      data: {...data, 'synced': 1},
    );
  }

  // ── Ajouter une école gérée ──────────────────────────────
  Future<void> _addManagedSchool() async {
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_business, color: Colors.orange),
            SizedBox(width: 10),
            Text('Ajouter une école', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nom de l\'école',
                prefixIcon: const Icon(Icons.school, color: Colors.orange),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cityCtrl,
              decoration: InputDecoration(
                labelText: 'Ville',
                prefixIcon: const Icon(
                  Icons.location_city,
                  color: Colors.orange,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim().toLowerCase();
              final city = cityCtrl.text.trim().toLowerCase();
              if (name.isEmpty || city.isEmpty) return;

              // Vérifier si déjà présente
              final exists = _managedSchools.any(
                (s) => s['name'] == name && s['city'] == city,
              );
              if (exists) {
                Navigator.pop(ctx);
                return;
              }

              // Ajouter dans Firestore
              await FirestoreService.addManagedSchool(
                adminId: widget.admin.id!,
                schoolName: name,
                schoolCity: city,
              );

              // Ajouter dans SQLite
              final newSchools = [
                ..._managedSchools,
                {'name': name, 'city': city},
              ];
              // Exclure l'école principale de la liste managed_schools
              final primary = {
                'name': widget.admin.schoolName.trim().toLowerCase(),
                'city': widget.admin.schoolCity.trim().toLowerCase(),
              };
              final extrasOnly = newSchools
                  .where(
                    (s) =>
                        s['name'] != primary['name'] ||
                        s['city'] != primary['city'],
                  )
                  .toList();
              await DBService.updateManagedSchools(
                adminId: widget.admin.id!,
                schools: extrasOnly,
              );

              if (mounted) {
                setState(() => _managedSchools = [primary, ...extrasOnly]);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ École ajoutée : $name — $city'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Retirer une école gérée ──────────────────────────────
  Future<void> _removeManagedSchool(Map<String, String> school) async {
    // Ne pas supprimer l'école principale
    final primary = {
      'name': widget.admin.schoolName.trim().toLowerCase(),
      'city': widget.admin.schoolCity.trim().toLowerCase(),
    };
    if (school['name'] == primary['name'] &&
        school['city'] == primary['city']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de retirer l\'école principale'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Retirer l\'école ?'),
        content: Text('${school['name']} — ${school['city']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirestoreService.removeManagedSchool(
      adminId: widget.admin.id!,
      schoolName: school['name']!,
      schoolCity: school['city']!,
    );

    final newSchools = _managedSchools
        .where(
          (s) => s['name'] != school['name'] || s['city'] != school['city'],
        )
        .toList();
    final extrasOnly = newSchools
        .where(
          (s) => s['name'] != primary['name'] || s['city'] != primary['city'],
        )
        .toList();
    await DBService.updateManagedSchools(
      adminId: widget.admin.id!,
      schools: extrasOnly,
    );

    if (mounted) {
      setState(() {
        _managedSchools = newSchools;
        if (_selectedSchool?['name'] == school['name'] &&
            _selectedSchool?['city'] == school['city']) {
          _selectedSchool = null;
        }
      });
    }
  }

  // ── Activer / Désactiver ─────────────────────────────────
  Future<void> _toggleActive(Map<String, dynamic> teacher) async {
    final id = teacher['local_id'] as int? ?? teacher['id'] as int;
    final active = (teacher['is_active'] as int? ?? 1) == 1;
    await _firestoreUpdate(id, {'is_active': active ? 0 : 1});
  }

  // ── Archiver ─────────────────────────────────────────────
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

  // ── Supprimer ────────────────────────────────────────────
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
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc('teacher_$id')
          .delete();
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

  // ── Ajouter / Modifier professeur ───────────────────────
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

    // École du nouveau prof = école filtrée actuellement
    final targetSchool = _selectedSchool ?? _managedSchools.first;

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
              // Info école cible
              if (!isEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${targetSchool['name']} — ${targetSchool['city']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  schoolName: targetSchool['name']!,
                  schoolCity: targetSchool['city']!,
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

  // ── Migration school_keys ────────────────────────────────
  Future<void> _migrateSchoolKeys() async {
    try {
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
        final docKey = '${rawName}__${rawCity}';
        final rawKey = data['school_key'] as String?;
        if (rawKey == null || rawKey.isEmpty || rawKey != docKey) {
          batch.update(doc.reference, {
            'school_name': rawName,
            'school_city': rawCity,
            'school_key': docKey,
          });
          count++;
        }
      }
      if (count > 0) await batch.commit();
    } catch (e) {}
  }

  // ── Sync Firestore → SQLite ──────────────────────────────
  void _syncToSQLite(List<Map<String, dynamic>> firestoreTeachers) {
    for (final t in firestoreTeachers) {
      final id = t['local_id'] as int? ?? t['id'] as int?;
      if (id == null) continue;
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
          'school_name': (t['school_name'] as String? ?? '')
              .toLowerCase()
              .trim(),
          'school_city': (t['school_city'] as String? ?? '')
              .toLowerCase()
              .trim(),
          'synced': 1,
        },
      ).catchError((_) {});
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
  // BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final schoolKeys = _managedSchools
        .map((s) => '${s['name']}__${s['city']}')
        .toList();

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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // ✅ Stream sur l'école filtrée OU toutes les écoles
        stream: _selectedSchool != null
            ? FirestoreService.streamTeachersInSchool(
                widget.admin,
                filterSchoolKey: _currentSchoolKey,
              )
            : FirestoreService.streamTeachersAllManagedSchools(widget.admin),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }
          if (snapshot.hasError) return _buildWithSQLite(t);

          final allTeachers = snapshot.data ?? [];
          _syncToSQLite(allTeachers);
          final teachers = _searchFilter(allTeachers);
          final total = allTeachers.length;
          final active = allTeachers.where((t) => t['is_active'] == 1).length;

          return _buildBody(t, teachers, total, active);
        },
      ),
    );
  }

  // ── Fallback SQLite ──────────────────────────────────────
  Widget _buildWithSQLite(AppLocalizations t) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DBService.getTeachersForAdmin(
        admin: widget.admin,
        filterSchoolName: _selectedSchool?['name'],
        filterSchoolCity: _selectedSchool?['city'],
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
          const SizedBox(height: 12),
          // ✅ Filtre par école
          _buildSchoolFilter(),
          const SizedBox(height: 12),
          _buildSearchBar(t),
          const SizedBox(height: 12),
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
    final schoolLabel = _selectedSchool != null
        ? '${_selectedSchool!['name']} — ${_selectedSchool!['city']}'
        : 'Toutes les écoles (${_managedSchools.length})';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D4037), Color(0xFF795548)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D4037).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_managedSchools.length} école${_managedSchools.length > 1 ? "s" : ""} gérée${_managedSchools.length > 1 ? "s" : ""}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // ✅ Bouton gérer les écoles
              GestureDetector(
                onTap: _showManageSchoolsSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Gérer',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

  // ── Filtre écoles (chips) ─────────────────────────────────
  Widget _buildSchoolFilter() {
    if (_managedSchools.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Chip "Toutes"
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSchool = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _selectedSchool == null ? Colors.orange : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedSchool == null
                        ? Colors.orange
                        : Colors.orange.shade200,
                  ),
                  boxShadow: _selectedSchool == null
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Toutes (${_managedSchools.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _selectedSchool == null
                        ? Colors.white
                        : Colors.orange,
                  ),
                ),
              ),
            ),
          ),
          // Chip par école
          ..._managedSchools.map((school) {
            final isSelected =
                _selectedSchool?['name'] == school['name'] &&
                _selectedSchool?['city'] == school['city'];
            final isPrimary =
                school['name'] ==
                    widget.admin.schoolName.trim().toLowerCase() &&
                school['city'] == widget.admin.schoolCity.trim().toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedSchool = school),
                onLongPress: isPrimary
                    ? null
                    : () => _removeManagedSchool(school),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF5D4037) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF5D4037)
                          : Colors.brown.shade200,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF5D4037).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPrimary ? Icons.star : Icons.school,
                        size: 11,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF5D4037),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${school['name']} · ${school['city']}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF5D4037),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Bouton "+"
          GestureDetector(
            onTap: _addManagedSchool,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Ajouter',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom sheet gérer les écoles ─────────────────────────
  void _showManageSchoolsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Text(
                'Écoles gérées',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Liste des écoles
              ..._managedSchools.map((school) {
                final isPrimary =
                    school['name'] ==
                        widget.admin.schoolName.trim().toLowerCase() &&
                    school['city'] ==
                        widget.admin.schoolCity.trim().toLowerCase();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.orange.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPrimary
                          ? Colors.orange.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPrimary ? Icons.star : Icons.school,
                        color: isPrimary ? Colors.orange : Colors.brown,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              school['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              school['city'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Principale',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _removeManagedSchool(school);
                          },
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              // Bouton ajouter
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_business, color: Colors.orange),
                  label: const Text(
                    'Ajouter une école',
                    style: TextStyle(color: Colors.orange),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addManagedSchool();
                  },
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildTeacherCard(AppLocalizations t, Map<String, dynamic> teacher) {
    final id = teacher['local_id'] as int? ?? teacher['id'] as int? ?? 0;
    final fullName =
        '${teacher['first_name'] ?? ''} ${teacher['last_name'] ?? ''}'.trim();
    final email = teacher['email'] as String? ?? '';
    final active = (teacher['is_active'] as int? ?? 1) == 1;
    final role = teacher['role'] as String? ?? 'teacher';
    final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
    final isAdmin = role == 'admin' || role == 'super_admin';
    final schoolName = teacher['school_name'] as String? ?? '';
    final schoolCity = teacher['school_city'] as String? ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: DBService.getTeacherStats(id),
      builder: (ctx, statsSnap) {
        final stats = statsSnap.data ?? {'classes': 0, 'students': 0};
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
                      ? const Color(0xFFD7B896)
                      : Colors.grey.shade200,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: active ? const Color(0xFF5D4037) : Colors.grey,
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
                    // ✅ Badge école (utile si multi-école)
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
                        '🏫 $schoolName — $schoolCity',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7B896),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role == 'super_admin' ? '👑 Super' : '🔑 Admin',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      '📚 ${stats['classes']}  👦 ${stats['students']}',
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
            const Icon(
              Icons.people_outline,
              size: 64,
              color: Color(0xFFD7B896),
            ),
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
