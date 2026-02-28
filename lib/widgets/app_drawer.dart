import 'package:flutter/material.dart';
import '../models/teachers.dart';
import '../l10n/app_localizations.dart';

// ✅ SÉCURITÉ : aucun changement de rôle possible depuis le drawer
// Le rôle est défini UNIQUEMENT dans Firestore par le super-admin
// et lu depuis SQLite au login (sync descendante)

class AppDrawer extends StatelessWidget {
  final Function(int) onSelect;
  final Teacher user;
  final Future<void> Function() onLogout;

  const AppDrawer({
    super.key,
    required this.onSelect,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isAdmin = user.role == 'admin' || user.role == 'super_admin';

    final roleBg = isAdmin ? const Color(0xFF6A1B9A) : Colors.orange;
    final roleLabel = user.role == 'super_admin'
        ? '👑 ${t.roleSuperAdmin}'
        : isAdmin
        ? '🔑 ${t.roleAdmin}'
        : '👤 ${t.roleTeacher}';

    return Drawer(
      child: Column(
        children: [
          // ─── Header — lecture seule, pas cliquable ───────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [roleBg, roleBg.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(
                    user.firstName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${user.firstName} ${user.lastName ?? ''}'.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Navigation ──────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _NavTile(
                  icon: Icons.dashboard_rounded,
                  label: t.home,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(0);
                  },
                ),
                _NavTile(
                  icon: Icons.class_rounded,
                  label: t.myClasses,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(1);
                  },
                ),
                if (isAdmin) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      t.administration.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black38,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  _NavTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: t.administration,
                    color: const Color(0xFF6A1B9A),
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelect(2);
                    },
                  ),
                ],
              ],
            ),
          ),

          // ─── Déconnexion ─────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              title: Text(
                t.logout,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.black26,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
