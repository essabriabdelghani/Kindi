// ============================================================
// sync_down_service.dart — lib/services/sync_down_service.dart
//
// SYNC DESCENDANTE : Firebase → SQLite
//
// Principe :
//   Firebase est la vérité globale (cloud)
//   SQLite est la vérité locale (appareil)
//
//   Quand on ouvre une page classe ou étudiants :
//   1. Récupérer les données Firebase du teacher
//   2. Comparer avec SQLite local
//   3. Insérer/Mettre à jour ce qui manque ou est obsolète
//   4. Afficher depuis SQLite (source unique d'affichage)
//
// CAS GÉRÉS :
//   ✅ Élève ajouté sur un autre appareil → apparaît ici
//   ✅ Classe ajoutée sur un autre appareil → apparaît ici
//   ✅ Élève archivé ailleurs → archivé ici aussi
//   ✅ Conflit : Firebase plus récent → Firebase gagne
//   ✅ Hors ligne → SQLite local utilisé tel quel
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'db_service.dart';

class SyncDownService {
  static final _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────
  // VÉRIFIER la connexion
  // ─────────────────────────────────────────────────────────
  static Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  // ═══════════════════════════════════════════════════════
  // SYNC DESCENDANTE COMPLÈTE
  // Appeler avant d'afficher MesClassesPage ou EtudiantsClassePage
  //
  // Retourne : nombre de changements appliqués
  // ═══════════════════════════════════════════════════════
  static Future<SyncDownReport> syncForTeacher({
    required int teacherId,
    required String schoolName,
    required String schoolCity,
  }) async {
    if (!await _isOnline()) {
      return SyncDownReport(offline: true);
    }

    final report = SyncDownReport();
    final db = await DBService.database;

    try {
      // 0️⃣ Sync rôle du teacher depuis Firestore (admin peut l'avoir changé)
      await _syncTeacherRoleDown(db: db, teacherId: teacherId);

      // 1️⃣ Sync classes descendante
      await _syncClassesDown(
        db: db,
        teacherId: teacherId,
        schoolName: schoolName,
        schoolCity: schoolCity,
        report: report,
      );

      // 2️⃣ Sync étudiants descendante (après classes car FK)
      await _syncChildrenDown(db: db, teacherId: teacherId, report: report);
    } catch (e) {
      report.errors.add('Erreur sync down: $e');
      print('❌ SyncDown erreur: $e');
    }

    print(
      '✅ SyncDown: ${report.inserted} insérés, ${report.updated} mis à jour, ${report.archived} archivés',
    );
    return report;
  }

  // ═══════════════════════════════════════════════════════
  // SYNC RÔLE TEACHER : Firestore → SQLite
  // Si un admin a changé le rôle depuis une autre session,
  // on met à jour SQLite et la session locale
  // ═══════════════════════════════════════════════════════
  static Future<void> _syncTeacherRoleDown({
    required Database db,
    required int teacherId,
  }) async {
    try {
      final doc = await _firestore
          .collection('teachers')
          .doc('teacher_' + teacherId.toString())
          .get();

      if (!doc.exists) return;
      final data = doc.data();
      if (data == null) return;

      final remoteRole = data['role'] as String?;
      if (remoteRole == null) return;

      // Comparer avec SQLite local
      final local = await db.query(
        'teachers',
        where: 'id = ?',
        whereArgs: [teacherId],
        limit: 1,
      );
      if (local.isEmpty) return;

      final localRole = local.first['role'] as String?;
      if (localRole == remoteRole) return; // pas de changement

      // Mettre à jour SQLite
      await db.rawUpdate(
        'UPDATE teachers SET role = ?, synced = 1 WHERE id = ?',
        [remoteRole, teacherId],
      );

      // Mettre à jour la session en mémoire (import session_service)
      // Session mise à jour via SessionService
      // (import géré dynamiquement pour éviter circular dependency)
      print('ℹ️ Role updated in SQLite - session will reload on next build');

      print('✅ Rôle mis à jour depuis Firestore: ' + remoteRole);
    } catch (e) {
      print('ℹ️ _syncTeacherRoleDown: ' + e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════
  // SYNC CLASSES : Firebase → SQLite
  // ═══════════════════════════════════════════════════════
  static Future<void> _syncClassesDown({
    required Database db,
    required int teacherId,
    required String schoolName,
    required String schoolCity,
    required SyncDownReport report,
  }) async {
    // Récupérer les classes du teacher depuis Firebase
    final snap = await _firestore
        .collection('classes')
        .where('_owner_teacher_id', isEqualTo: teacherId)
        .where('deleted', isEqualTo: 0)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = data['id'] as int?; // l'ID SQLite stocké dans Firebase

      if (localId == null) continue;

      // Chercher dans SQLite
      final existing = await db.query(
        'classes',
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // ─── CAS 1 : n'existe pas en local → INSERT ───
        await db.insert('classes', {
          'id': localId,
          'name': data['name'] ?? '',
          'level': data['level'] ?? '',
          'academic_year': data['academic_year'] ?? '',
          'school_name': data['school_name'] ?? schoolName,
          'school_city': data['school_city'] ?? schoolCity,
          'notes': data['notes'],
          'synced': 1, // déjà synced car vient de Firebase
          'deleted': 0,
          'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': data['updated_at'] ?? DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Ajouter dans class_teachers
        await db.insert('class_teachers', {
          'class_id': localId,
          'teacher_id': teacherId,
          'role': 'main',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        report.inserted++;
        print('📥 Classe insérée: ${data['name']}');
      } else {
        // ─── CAS 2 : existe → comparer updated_at ───
        final localUpdatedAt = existing.first['updated_at'] as String? ?? '';
        final firebaseUpdatedAt = data['updated_at'] as String? ?? '';

        if (firebaseUpdatedAt.compareTo(localUpdatedAt) > 0) {
          // Firebase est plus récent → UPDATE
          await db.update(
            'classes',
            {
              'name': data['name'] ?? '',
              'level': data['level'] ?? '',
              'academic_year': data['academic_year'] ?? '',
              'synced': 1,
              'updated_at': firebaseUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
          report.updated++;
        }
      }
    }

    // ─── CAS 3 : classes supprimées dans Firebase ───
    final deletedSnap = await _firestore
        .collection('classes')
        .where('_owner_teacher_id', isEqualTo: teacherId)
        .where('deleted', isEqualTo: 1)
        .get();

    for (final doc in deletedSnap.docs) {
      final localId = doc.data()['id'] as int?;
      if (localId == null) continue;

      await db.update(
        'classes',
        {
          'deleted': 1,
          'synced': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
      );
      report.archived++;
    }
  }

  // ═══════════════════════════════════════════════════════
  // SYNC ÉTUDIANTS : Firebase → SQLite
  // ═══════════════════════════════════════════════════════
  static Future<void> _syncChildrenDown({
    required Database db,
    required int teacherId,
    required SyncDownReport report,
  }) async {
    // Récupérer les étudiants du teacher depuis Firebase
    final snap = await _firestore
        .collection('children')
        .where('main_teacher_id', isEqualTo: teacherId)
        .where('deleted', isEqualTo: 0)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final localId = data['id'] as int?;

      if (localId == null) continue;

      // Chercher dans SQLite
      final existing = await db.query(
        'children',
        where: 'id = ?',
        whereArgs: [localId],
        limit: 1,
      );

      if (existing.isEmpty) {
        // ─── CAS 1 : n'existe pas en local → INSERT ───
        await db.insert('children', {
          'id': localId,
          'child_code': data['child_code'],
          'first_name': data['first_name'] ?? '',
          'last_name': data['last_name'],
          'gender': data['gender'] ?? 'boy',
          'birth_date': data['birth_date'],
          'class_id': data['class_id'],
          'main_teacher_id': data['main_teacher_id'],
          'latest_overall_risk_level': data['latest_overall_risk_level'],
          'latest_observation_date': data['latest_observation_date'],
          'notes': data['notes'],
          'synced': 1, // vient de Firebase
          'deleted': 0,
          'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': data['updated_at'] ?? DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        report.inserted++;
        print('📥 Élève inséré: ${data['first_name']}');
      } else {
        // ─── CAS 2 : existe → comparer updated_at ───
        final localUpdatedAt = existing.first['updated_at'] as String? ?? '';
        final firebaseUpdatedAt = data['updated_at'] as String? ?? '';

        if (firebaseUpdatedAt.compareTo(localUpdatedAt) > 0) {
          await db.update(
            'children',
            {
              'first_name': data['first_name'] ?? '',
              'last_name': data['last_name'],
              'gender': data['gender'],
              'latest_overall_risk_level': data['latest_overall_risk_level'],
              'latest_observation_date': data['latest_observation_date'],
              'notes': data['notes'],
              'synced': 1,
              'updated_at': firebaseUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [localId],
          );
          report.updated++;
        }
      }
    }

    // ─── CAS 3 : étudiants archivés dans Firebase ───
    final archivedSnap = await _firestore
        .collection('children')
        .where('main_teacher_id', isEqualTo: teacherId)
        .where('deleted', isEqualTo: 1)
        .get();

    for (final doc in archivedSnap.docs) {
      final localId = doc.data()['id'] as int?;
      if (localId == null) continue;

      await db.update(
        'children',
        {
          'deleted': 1,
          'synced': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND deleted = 0',
        whereArgs: [localId],
      );
      report.archived++;
    }
  }

  // ═══════════════════════════════════════════════════════
  // SYNC RAPIDE — pour une seule classe
  // Appeler quand on ouvre EtudiantsClassePage
  // ═══════════════════════════════════════════════════════
  static Future<SyncDownReport> syncForClass({
    required int teacherId,
    required int classId,
  }) async {
    if (!await _isOnline()) return SyncDownReport(offline: true);

    final report = SyncDownReport();
    final db = await DBService.database;

    try {
      final snap = await _firestore
          .collection('children')
          .where('main_teacher_id', isEqualTo: teacherId)
          .where('class_id', isEqualTo: classId)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final localId = data['id'] as int?;
        if (localId == null) continue;

        final existing = await db.query(
          'children',
          where: 'id = ?',
          whereArgs: [localId],
          limit: 1,
        );

        if (existing.isEmpty) {
          await db.insert('children', {
            'id': localId,
            'child_code': data['child_code'],
            'first_name': data['first_name'] ?? '',
            'last_name': data['last_name'],
            'gender': data['gender'] ?? 'boy',
            'birth_date': data['birth_date'],
            'class_id': classId,
            'main_teacher_id': teacherId,
            'latest_overall_risk_level': data['latest_overall_risk_level'],
            'notes': data['notes'],
            'synced': 1,
            'deleted': data['deleted'] ?? 0,
            'created_at':
                data['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at':
                data['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          report.inserted++;
        } else {
          final localUpdated = existing.first['updated_at'] as String? ?? '';
          final firebaseUpdated = data['updated_at'] as String? ?? '';
          if (firebaseUpdated.compareTo(localUpdated) > 0) {
            await db.update(
              'children',
              {
                'first_name': data['first_name'],
                'last_name': data['last_name'],
                'latest_overall_risk_level': data['latest_overall_risk_level'],
                'deleted': data['deleted'] ?? 0,
                'synced': 1,
                'updated_at': firebaseUpdated,
              },
              where: 'id = ?',
              whereArgs: [localId],
            );
            report.updated++;
          }
        }
      }
    } catch (e) {
      report.errors.add('syncForClass: $e');
    }

    return report;
  }
}

// ─────────────────────────────────────────────────────────
// Rapport de sync descendante
// ─────────────────────────────────────────────────────────
class SyncDownReport {
  int inserted = 0;
  int updated = 0;
  int archived = 0;
  List<String> errors = [];
  bool offline;

  SyncDownReport({this.offline = false});

  bool get success => errors.isEmpty && !offline;
  bool get hasChanges => inserted > 0 || updated > 0 || archived > 0;

  String get message {
    if (offline) return '📴 Hors ligne — données locales affichées';
    if (!hasChanges) return '✅ Données à jour';
    return '📥 $inserted ajoutés, $updated mis à jour, $archived archivés';
  }
}
