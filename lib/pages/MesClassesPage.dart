import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart'; // ✅ Fix : ConflictAlgorithm
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../services/sync_engine.dart';
import '../services/sync_down_service.dart';
import 'EtudiantsClassePage.dart';

class MesClassesPage extends StatefulWidget {
  final Teacher user;
  const MesClassesPage({super.key, required this.user});

  @override
  State<MesClassesPage> createState() => _MesClassesPageState();
}

class _MesClassesPageState extends State<MesClassesPage> {
  late Future<List<Map<String, dynamic>>> futureClasses;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // ✅ Au démarrage : sync descendante puis afficher
    _syncThenLoad();
  }

  // ─────────────────────────────────────────────────────────
  // 1. Télécharger depuis Firebase
  // 2. Afficher depuis SQLite (toujours à jour)
  // ─────────────────────────────────────────────────────────
  Future<void> _syncThenLoad() async {
    setState(() => _syncing = true);

    // Sync descendante : Firebase → SQLite
    final report = await SyncDownService.syncForTeacher(
      teacherId: widget.user.id!,
      schoolName: widget.user.schoolName,
      schoolCity: widget.user.schoolCity,
    );

    if (report.hasChanges) {
      print('📥 Classes sync: ${report.message}');
    }

    // Afficher depuis SQLite (maintenant à jour)
    _refreshClasses();
    setState(() => _syncing = false);
  }

  void _refreshClasses() {
    futureClasses = DBService.getClassesByTeacher(widget.user.id!);
    setState(() {});
  }

  void _showAddClassDialog(BuildContext context) {
    final classCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final suggestions = ["Petite Section", "Moyenne Section", "Grande Section"];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text("Ajouter une classe"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: classCtrl,
                decoration: const InputDecoration(
                  labelText: "Nom de la classe *",
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setD(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: levelCtrl,
                decoration: const InputDecoration(
                  labelText: "Niveau (PS, MS, GS...)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: suggestions
                    .map(
                      (s) => ActionChip(
                        label: Text(s),
                        onPressed: () {
                          classCtrl.text = s;
                          levelCtrl.text = s.split(' ').first;
                          setD(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                final name = classCtrl.text.trim();
                if (name.isEmpty) return;

                final db = await DBService.database;
                final now = DateTime.now().toIso8601String();

                final classId = await db.insert('classes', {
                  'name': name,
                  'level': levelCtrl.text.trim().isNotEmpty
                      ? levelCtrl.text.trim()
                      : name.split(' ').first,
                  'academic_year': '2025-2026',
                  'school_name': widget.user.schoolName,
                  'school_city': widget.user.schoolCity,
                  'synced': 0,
                  'deleted': 0,
                  'created_at': now,
                  'updated_at': now,
                });

                await db.insert('class_teachers', {
                  'class_id': classId,
                  'teacher_id': widget.user.id!,
                  'role': 'main',
                }, conflictAlgorithm: ConflictAlgorithm.ignore);

                // ✅ Sync montante : envoyer à Firebase
                SyncEngine.syncAll(teacherId: widget.user.id!);

                if (ctx.mounted) Navigator.pop(ctx);
                _refreshClasses();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Classe ajoutée ✅"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text(
                "Ajouter",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteClass(int classId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer la classe"),
        content: Text("Supprimer '$name' ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final db = await DBService.database;
    final now = DateTime.now().toIso8601String();

    // 1) Marquer les enfants de cette classe comme supprimés
    await db.update(
      'children',
      {'deleted': 1, 'synced': 0, 'updated_at': now},
      where: 'class_id = ? AND deleted = 0',
      whereArgs: [classId],
    );

    // 2) Supprimer class_teachers local
    await db.delete(
      'class_teachers',
      where: 'class_id = ?',
      whereArgs: [classId],
    );

    // 3) Marquer la classe comme supprimée SQLite
    await db.update(
      'classes',
      {'deleted': 1, 'synced': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [classId],
    );

    // 4) Supprimer dans Firestore
    try {
      final fs = FirebaseFirestore.instance;
      // Supprimer la classe
      await fs.collection('classes').doc('class_$classId').delete();
      // Supprimer les enfants de cette classe dans Firestore
      final childrenSnap = await fs
          .collection('children')
          .where('class_id', isEqualTo: classId)
          .get();
      for (final doc in childrenSnap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('ℹ️ Suppression Firestore classe: $e');
    }

    SyncEngine.syncAll(teacherId: widget.user.id!);
    _refreshClasses();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width > 800 ? 800.0 : width * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddClassDialog(context),
      ),
      body: Center(
        child: SizedBox(
          width: maxWidth,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _syncing
                // ✅ Indicateur pendant la sync descendante
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.orange),
                        SizedBox(height: 15),
                        Text(
                          "Synchronisation...",
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: futureClasses,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text("Erreur : ${snapshot.error}"),
                        );
                      }
                      final classes = snapshot.data ?? [];
                      if (classes.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.class_,
                                size: 60,
                                color: Colors.orange,
                              ),
                              SizedBox(height: 15),
                              Text(
                                "Aucune classe trouvée.",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Appuyez sur + pour en ajouter une.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return RefreshIndicator(
                        color: Colors.orange,
                        // ✅ Pull-to-refresh = re-sync depuis Firebase
                        onRefresh: _syncThenLoad,
                        child: ListView.builder(
                          itemCount: classes.length,
                          itemBuilder: (context, i) {
                            final c = classes[i];
                            return _ClassCard(
                              classe: c['name'] ?? '',
                              niveau: c['level'] ?? '',
                              annee: c['academic_year'] ?? '',
                              classId: c['id'],
                              user: widget.user,
                              onDelete: () =>
                                  _deleteClass(c['id'], c['name'] ?? ''),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String classe, niveau, annee;
  final int classId;
  final Teacher user;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.classe,
    required this.niveau,
    required this.annee,
    required this.classId,
    required this.user,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EtudiantsClassePage(
                classId: classId,
                className: classe,
                mainTeacherId: user.id!,
              ),
            ),
          ).then((_) {
            // ✅ Quand on revient de EtudiantsClassePage → pas besoin de re-sync
            // car EtudiantsClassePage gère sa propre sync
          }),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.class_, color: Colors.orange, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classe,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (niveau.isNotEmpty)
                    Text(
                      "Niveau : $niveau",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  if (annee.isNotEmpty)
                    Text(
                      "Année : $annee",
                      style: const TextStyle(color: Colors.black54),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.orange),
          ],
        ),
      ),
    );
  }
}
