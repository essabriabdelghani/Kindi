import 'package:flutter/material.dart';
import 'package:kindi/pages/MesClassesPage.dart';
import 'package:kindi/pages/ProfHomePage.dart';
import 'package:kindi/pages/AdminPage.dart';
import 'package:kindi/pages/connexion_page.dart';
import 'package:kindi/widgets/app_drawer.dart';
import 'package:kindi/widgets/sync_status_widget.dart';
import '../models/teachers.dart';
import '../controllers/auth_controller.dart';
import '../widgets/language_selector.dart';

class MainLayout extends StatefulWidget {
  final Teacher user;
  const MainLayout({super.key, required this.user});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int selectedIndex = 0;

  bool get isAdmin =>
      widget.user.role == 'admin' || widget.user.role == 'super_admin';

  List<Widget> get pages {
    final list = <Widget>[
      ProfHomePage(user: widget.user), // 0 — Accueil
      MesClassesPage(user: widget.user), // 1 — Mes classes
    ];
    if (isAdmin) {
      list.add(AdminPage(admin: widget.user)); // 2 — Admin
    }
    return list;
  }

  String get pageTitle {
    switch (selectedIndex) {
      case 0:
        return 'Accueil';
      case 1:
        return 'Mes classes';
      case 2:
        return isAdmin ? 'Administration' : 'Kindi';
      default:
        return 'Kindi';
    }
  }

  void _onSelectPage(int index) {
    if (index < 0 || index >= pages.length) index = 0;
    setState(() => selectedIndex = index);
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    await AuthController.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ConnexionPage()),
      (route) => false,
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return '🔑 Administrateur';
      case 'super_admin':
        return '👑 Super Admin';
      default:
        return '👤 Professeur';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _roleLabel(widget.user.role),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
        actions: [
          // ✅ Sélecteur de langue
          const LanguageSelector(),
          // ✅ Sync status
          if (widget.user.id != null)
            SyncStatusWidget(teacherId: widget.user.id!),
        ],
      ),
      drawer: AppDrawer(
        onSelect: _onSelectPage,
        user: widget.user,
        onLogout: _logout,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[selectedIndex],
      ),
    );
  }
}
