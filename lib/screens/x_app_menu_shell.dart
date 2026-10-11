import 'package:flutter/material.dart';
import 'location_options_maintenance_screen.dart';
import 'settings_screen.dart';
import 'export_import_screen.dart';

class AppMenuShell extends StatelessWidget {
  const AppMenuShell({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX 1: Container -> Material so ListTile ink can paint (same color + radius, no more DecoratedBox assert)
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar - slightly darker than black26 for visibility
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Menu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A1A))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _menuTile(
                    context,
                    icon: Icons.account_tree_outlined,
                    title: 'Location Options',
                    subtitle: 'Generals & Specifics • Storage / Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocationMaintenanceScreen()));
                    },
                  ),
                  const Divider(height: 12, thickness: 0.5),
                  _menuTile(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Preferences, defaults',
                    onTap: () async {
                      final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      if (result is List<String> && result.length == 3 && context.mounted) {
                        Navigator.pop(context, result);
                      }
                    },
                  ),
                  _menuTile(
                    context,
                    icon: Icons.import_export_outlined,
                    title: 'Export / Import',
                    subtitle: 'ZIP backup with photos, restore',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportImportScreen()));
                    },
                  ),
                  _menuTile(context, icon: Icons.contact_support_outlined, title: 'Contact / Support', subtitle: 'Feedback, report issue', enabled: false),
                  _menuTile(context, icon: Icons.help_outline, title: 'Help', subtitle: 'How to use WhereLog', enabled: false),
                  const Divider(height: 12, thickness: 0.5),
                  _menuTile(context, icon: Icons.info_outline, title: 'About', subtitle: 'Version, data paths', enabled: false),
                  _menuTile(context, icon: Icons.exit_to_app, title: 'Close WhereLog', subtitle: 'Exit application', onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(BuildContext context,
      {required IconData icon, required String title, required String subtitle, VoidCallback? onTap, bool enabled = true}) {
    // FIX 2: Readability - replace black38/black45 with darker, readable disabled colors
    // Old: black38 (38% black) and black45 (45% black) - very light, hard to read
    // New: textDisabled #6B6B6B and textSecondary #444444 - WCAG readable, still looks disabled
    const textPrimary = Color(0xFF1A1A1A);
    const textSecondary = Color(0xFF444444);
    const textDisabled = Color(0xFF6B6B6B);

    return ListTile(
      enabled: enabled,
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(icon, size: 20, color: enabled ? textPrimary : textDisabled),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: enabled ? textPrimary : textDisabled),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 10.5, color: enabled ? textSecondary : textDisabled, height: 1.2),
      ),
      trailing: enabled ? const Icon(Icons.chevron_right, size: 16, color: textSecondary) : null,
      onTap: enabled ? onTap : null,
    );
  }
}
