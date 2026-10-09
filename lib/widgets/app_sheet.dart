import 'package:flutter/material.dart';
import '../screens/location_options_maintenance_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/export_import_screen.dart';

Future<T?> showModalTopSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color barrierColor = Colors.black54,
  Duration transitionDuration = const Duration(milliseconds: 220),
  double borderRadius = 16,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: "TopSheet",
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    pageBuilder: (ctx, a1, a2) {
      return Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(borderRadius)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(bottom: false, child: builder(ctx)),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

Future<dynamic> showAppMenu(BuildContext outerContext) async {
  final String? action = await showGeneralDialog<String>(
    context: outerContext,
    barrierDismissible: true,
    barrierLabel: "AppMenu",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, a1, a2) {
      return _SwipeableRightSheet(
        child: Builder(builder: (innerCtx) {
          const textPrimary = Color(0xFF1A1A1A);
          const textSecondary = Color(0xFF444444);
          const textDisabled = Color(0xFF6B6B6B);

          Widget menuTile({
            required IconData icon,
            required String title,
            required String subtitle,
            String? popValue,
            bool enabled = true,
            bool isDestructive = false,
          }) {
            final color = isDestructive ? Colors.red : (enabled ? textPrimary : textDisabled);
            final subColor = isDestructive ? Colors.red.shade400 : (enabled ? textSecondary : textDisabled);
            return ListTile(
              enabled: enabled,
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              leading: Icon(icon, size: 20, color: color),
              title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
              subtitle: Text(subtitle, style: TextStyle(fontSize: 10.5, color: subColor, height: 1.2)),
              trailing: enabled && !isDestructive ? const Icon(Icons.chevron_right, size: 16, color: textSecondary) : null,
              onTap: enabled ? () => Navigator.pop(innerCtx, popValue) : null,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Menu', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A1A))),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(innerCtx),
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
                    menuTile(icon: Icons.account_tree_outlined, title: 'Location Options', subtitle: 'Generals & Specifics • Storage / Inventory', popValue: 'location'),
                    const Divider(height: 12, thickness: 0.5),
                    menuTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Preferences, defaults', popValue: 'settings'),
                    menuTile(icon: Icons.import_export_outlined, title: 'Export / Import', subtitle: 'ZIP backup with photos, restore', popValue: 'export_import'),
                    menuTile(icon: Icons.contact_support_outlined, title: 'Contact / Support', subtitle: 'Feedback, report issue', enabled: false),
                    menuTile(icon: Icons.help_outline, title: 'Help', subtitle: 'How to use WhereLog', enabled: false),
                    const Divider(height: 12, thickness: 0.5),
                    menuTile(icon: Icons.info_outline, title: 'About', subtitle: 'Version, data paths', enabled: false),
                  ],
                ),
              ),
              const Spacer(),
              const Divider(height: 1, thickness: 1),
              menuTile(icon: Icons.logout, title: 'Logout', subtitle: 'Sign out of WhereLog', isDestructive: true, popValue: 'logout'),
              const SizedBox(height: 8),
            ],
          );
        }),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );

  if (action == null || !outerContext.mounted) return null;
  switch (action) {
    case 'location':
      await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const LocationMaintenanceScreen()));
      return null;
    case 'settings':
      final result = await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      return result;
    case 'export_import':
      await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const ExportImportScreen()));
      return null;
    case 'logout':
      final confirmed = await showLogoutConfirm(outerContext);
      if (confirmed == true) {}
      return confirmed;
    default:
      return null;
  }
}

class _SwipeableRightSheet extends StatefulWidget {
  final Widget child;
  const _SwipeableRightSheet({required this.child});
  @override
  State<_SwipeableRightSheet> createState() => _SwipeableRightSheetState();
}

class _SwipeableRightSheetState extends State<_SwipeableRightSheet> {
  double _dragDx = 0;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 0) {
            setState(() => _dragDx += details.delta.dx);
          } else {
            setState(() => _dragDx = (_dragDx + details.delta.dx).clamp(0, double.infinity));
          }
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.velocity.pixelsPerSecond.dx;
          if (_dragDx > 100 || velocity > 600) {
            Navigator.pop(context);
          } else {
            setState(() => _dragDx = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(_dragDx, 0),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.78,
              height: double.infinity,
              child: SafeArea(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showLogoutConfirm(BuildContext context) {
  return showModalTopSheet<bool>(
    context: context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text("Logout?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text("Are you sure you want to logout?"),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          const SizedBox(width: 8),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ]),
      ]),
    ),
  );
}
