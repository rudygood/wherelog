import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/location_options_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/export_import_screen.dart';
import '../screens/about_screen.dart';

Future<T?> showModalTopSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, StateSetter setModal) builder,
  Color barrierColor = AppColors.barrier,
  Duration transitionDuration = const Duration(milliseconds: 220),
  double borderRadius = 16,
  double? maxWidth,
  Color? backgroundColor,
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
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.only(
              top: 60,
              left: maxWidth != null ? 0 : 12,
              right: maxWidth != null ? 0 : 12,
            ),
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? double.infinity,
            ),
            decoration: BoxDecoration(
              color: backgroundColor ?? (maxWidth != null ? AppColors.white : AppColors.cardSelected),
              borderRadius: BorderRadius.circular(AppRadius.sheet),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              bottom: false,
              child: StatefulBuilder(
                builder: (ctx2, setModal) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: builder(ctx2, setModal),
                  );
                },
              ),
            ),
          ),
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
    barrierColor: AppColors.barrier,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, a1, a2) {
      return _SwipeableRightSheet(
        child: Builder(builder: (innerCtx) {
          const textPrimary = AppColors.textPrimary;
          const textSecondary = AppColors.textSecondary;
          const textDisabled = AppColors.textDisabled;

          Widget menuTile({
            required IconData icon,
            required String title,
            required String subtitle,
            String? popValue,
            bool enabled = true,
            bool isDestructive = false,
          }) {
            final color = isDestructive ? AppColors.alert : (enabled ? textPrimary : textDisabled);
            final subColor = isDestructive ? AppColors.alert : (enabled ? textSecondary : textDisabled);
            return ListTile(
              enabled: enabled,
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              leading: Icon(icon, size: 20, color: color),
              title: Text(title, style: isDestructive ? AppText.menuTileTitleAlert : AppText.menuTileTitle.copyWith(color: color)),
              subtitle: Text(subtitle, style: isDestructive ? AppText.dialogAlert : AppText.dialog.copyWith(color: subColor)),
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
                    const Text('Menu', style: AppText.cardTitle),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    menuTile(icon: Icons.account_tree_outlined, title: 'Location Options', subtitle: 'Generals & Specifics • Storage / Inventory', popValue: 'location'),
                    const Divider(height: 12, thickness: 0.5),
                    menuTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Preferences, defaults', popValue: 'settings'),
                    menuTile(icon: Icons.import_export_outlined, title: 'Export / Import', subtitle: 'ZIP backup with photos, restore', popValue: 'export_import'),
                    menuTile(icon: Icons.contact_support_outlined, title: 'Contact / Support', subtitle: 'Feedback, report issue', enabled: false),
                    menuTile(icon: Icons.help_outline, title: 'Help', subtitle: 'How to use WhereLog', enabled: false),
                    const Divider(height: 12, thickness: 0.5),
                    menuTile(icon: Icons.info_outline, title: 'About', subtitle: 'Version, data paths', popValue: 'about'),
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
      await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const LocationOptionsScreen()));
      return null;
    case 'settings':
      final result = await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      return result;
    case 'export_import':
      await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const ExportImportScreen()));
      return null;
    case 'about':
      await Navigator.of(outerContext).push(MaterialPageRoute(builder: (_) => const AboutScreen()));
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
            color: AppColors.white,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppRadius.sheet)),
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
    maxWidth: 360,
    builder: (ctx, _) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Logout?", style: AppText.dialogTitleAlert),
        const SizedBox(height: 8),
        const Text("Are you sure you want to logout?"),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          const SizedBox(width: 8),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Logout", style: AppText.buttonSmallAlert)),
        ]),
      ],
    ),
  );
}

