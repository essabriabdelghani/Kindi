import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kindi/pages/MesClassesPage.dart';
import 'package:kindi/pages/DashboardPage.dart';
import 'package:kindi/pages/AdminPage.dart';
import 'package:kindi/pages/connexion_page.dart';
import 'package:kindi/widgets/app_drawer.dart';
import 'package:kindi/widgets/sync_status_widget.dart';
import '../models/teachers.dart';
import '../services/db_service.dart';
import '../services/session_service.dart';
import '../controllers/auth_controller.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';

class MainLayout extends StatefulWidget {
  final Teacher user;
  const MainLayout({super.key, required this.user});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;
  Teacher? _currentUser; // user local mutable
  StreamSubscription? _roleSub; // listener Firestore sur le rôle

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _listenRoleChanges();
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    super.dispose();
  }

  // ── Listener temps réel sur le document Firestore du user ──
  void _listenRoleChanges() {
    final userId = widget.user.id;
    if (userId == null) return;

    _roleSub = FirebaseFirestore.instance
        .collection('teachers')
        .doc('teacher_$userId')
        .snapshots()
        .listen(
          (doc) async {
            if (!doc.exists || !mounted) return;

            final data = doc.data();
            final remoteRole = data?['role'] as String?;
            if (remoteRole == null) return;

            final currentRole = _currentUser?.role ?? widget.user.role;
            if (remoteRole == currentRole) return; // pas de changement

            // ── Mettre à jour SQLite ──
            final db = await DBService.database;
            await db.rawUpdate(
              'UPDATE teachers SET role = ?, synced = 1 WHERE id = ?',
              [remoteRole, userId],
            );

            // ── Mettre à jour la session en mémoire ──
            final updated = (_currentUser ?? widget.user).copyWith(
              role: remoteRole,
            );
            SessionService.currentUser = updated;

            // ── Rebuild l'interface ──
            if (mounted) {
              setState(() {
                _currentUser = updated;
                // Si on était sur admin (index 2) et on n'est plus admin → revenir à 0
                if (!_isAdminRole(remoteRole) && selectedIndex >= 2) {
                  selectedIndex = 0;
                }
              });

              // Notifier l'utilisateur
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Votre rôle a été mis à jour : $remoteRole'),
                  backgroundColor: Colors.purple,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          onError: (e) {
            // Firestore offline → silencieux
            debugPrint('ℹ️ Role listener offline: $e');
          },
        );
  }

  bool _isAdminRole(String role) => role == 'admin' || role == 'super_admin';

  Teacher get user => _currentUser ?? widget.user;

  bool get isAdmin => _isAdminRole(user.role);

  List<Widget> get pages {
    final list = <Widget>[
      DashboardPage(user: user),
      MesClassesPage(user: user),
    ];
    if (isAdmin) list.add(AdminPage(admin: user));
    return list;
  }

  void _onSelectPage(int index) {
    final maxIndex = pages.length - 1;
    setState(() => selectedIndex = index.clamp(0, maxIndex));
  }

  Future<void> _logout() async {
    _roleSub?.cancel();
    await AuthController.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ConnexionPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final titles = [t.home, t.myClasses, t.administration];
    final pageTitle = titles[selectedIndex.clamp(0, titles.length - 1)];

    final roleLabel = user.role == 'super_admin'
        ? '👑 ${t.roleSuperAdmin}'
        : user.role == 'admin'
        ? '🔑 ${t.roleAdmin}'
        : '👤 ${t.roleTeacher}';

    return Scaffold(
      backgroundColor: const Color(0xFFFCEFE3),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        elevation: 3,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              pageTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          const LanguageSelector(),
          if (user.id != null) SyncStatusWidget(teacherId: user.id!),
        ],
      ),
      drawer: AppDrawer(onSelect: _onSelectPage, user: user, onLogout: _logout),
      body: IndexedStack(index: selectedIndex, children: pages),
    );
  }
}
