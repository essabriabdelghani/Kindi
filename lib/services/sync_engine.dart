import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'db_service.dart';

class SyncEngine {
  static final _firestore = FirebaseFirestore.instance;
  static bool _isSyncing = false;
  static StreamSubscription? _connectivitySub;

  // ─────────────────────────────────────────────────────────
  // WATCHER CONNECTIVITÉ
  // Appeler une fois après Firebase.initializeApp()
  // ─────────────────────────────────────────────────────────
  static void startConnectivityWatcher({required int teacherId}) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected) syncAll(teacherId: teacherId);
    });
  }

  static void stopWatcher() => _connectivitySub?.cancel();

  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  // ─────────────────────────────────────────────────────────
  // SYNC TOUT
  // ─────────────────────────────────────────────────────────
  static Future<SyncReport> syncAll({required int teacherId}) async {
    if (_isSyncing) return SyncReport(skipped: true);
    if (!await isOnline()) return SyncReport(offline: true);

    _isSyncing = true;
    final report = SyncReport();

    try {
      final db = await DBService.database;

      // Ordre : teachers → classes → class_teachers → children → observations → answers
      await _syncTable(
        db: db,
        table: 'teachers',
        collection: 'teachers',
        idPrefix: 'teacher',
        report: report,
        extraFields: {'_synced_at': FieldValue.serverTimestamp()},
      );

      await _syncTable(
        db: db,
        table: 'classes',
        collection: 'classes',
        idPrefix: 'class',
        report: report,
        extraFields: {
          '_synced_at': FieldValue.serverTimestamp(),
          '_owner_teacher_id': teacherId,
        },
      );

      await _syncTable(
        db: db,
        table: 'class_teachers',
        collection: 'class_teachers',
        idPrefix: 'ct',
        report: report,
        extraFields: {'_synced_at': FieldValue.serverTimestamp()},
      );

      // Ajouter d'autres tables si nécessaire...

      // Sync des suppressions
      await _syncDeletions(db, report);
    } catch (e) {
      report.errors.add('Erreur syncAll: $e');
    } finally {
      _isSyncing = false;
    }

    return report;
  }

  // ─────────────────────────────────────────────────────────
  static Future<void> _syncTable({
    required Database db,
    required String table,
    required String collection,
    required String idPrefix,
    required SyncReport report,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final rows = await db.query(table, where: 'synced = 0 AND deleted = 0');

    for (final row in rows) {
      try {
        final id = row['id'];
        final docId = '${idPrefix}_$id';
        final data = Map<String, dynamic>.from(row);

        data.remove('synced');
        data.addAll(extraFields);

        await _firestore
            .collection(collection)
            .doc(docId)
            .set(data, SetOptions(merge: true));

        await db.update(table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);

        report.synced++;
      } catch (e) {
        report.errors.add('$table[$row]: $e'); // row complet pour debug
      }
    }
  }

  static Future<void> _syncDeletions(Database db, SyncReport report) async {
    final tables = {'classes': 'class', 'class_teachers': 'ct'};

    for (final entry in tables.entries) {
      final rows = await db.query(
        entry.key,
        where: 'deleted = 1 AND synced = 0',
        columns: ['id'],
      );

      for (final row in rows) {
        try {
          await _firestore
              .collection(entry.key)
              .doc('${entry.value}_${row['id']}')
              .update({
                'deleted': 1,
                '_deleted_at': FieldValue.serverTimestamp(),
              });

          await db.update(
            entry.key,
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [row['id']],
          );

          report.synced++;
        } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  static Future<void> markUnsync(String table, int id) async {
    final db = await DBService.database;
    await db.update(table, {'synced': 0}, where: 'id = ?', whereArgs: [id]);
  }
}

// ─────────────────────────────────────────────────────────
// Rapport de sync
// ─────────────────────────────────────────────────────────
class SyncReport {
  int synced = 0;
  List<String> errors = [];
  bool offline;
  bool skipped;

  SyncReport({this.offline = false, this.skipped = false});

  bool get success => errors.isEmpty && !offline && !skipped;

  String get message {
    if (skipped) return '⏳ Sync déjà en cours';
    if (offline) return '📴 Hors ligne — données sauvegardées localement';
    if (errors.isEmpty) return '✅ $synced éléments synchronisés';
    return '⚠️ $synced OK — ${errors.length} erreur(s)';
  }
}
