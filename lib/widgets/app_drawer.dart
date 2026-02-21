import 'package:flutter/material.dart';
import '../models/teachers.dart';

class AppDrawer extends StatelessWidget {
  final Function(int) onSelect;
  final Teacher user;
  final Future<void> Function() onLogout; // ✅ callback logout Firebase

  const AppDrawer({
    super.key,
    required this.onSelect,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = user.role == 'admin' || user.role == 'super_admin';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.orange),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_circle, size: 60, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  '${user.firstName} ${user.lastName ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                // Badge rôle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _roleLabel(user.role),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.home, color: Colors.orange),
            title: const Text('Accueil'),
            onTap: () => onSelect(0),
          ),

          ListTile(
            leading: const Icon(Icons.class_, color: Colors.orange),
            title: const Text('Mes classes'),
            onTap: () => onSelect(1),
          ),

          if (isAdmin)
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.blue,
              ),
              title: const Text('Administration'),
              onTap: () => onSelect(2),
            ),

          const Divider(),

          // ✅ Fix : logout appelle AuthController.logout() via callback
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(context); // fermer le drawer d'abord
              await onLogout(); // puis logout Firebase + session
            },
          ),
        ],
      ),
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
}
