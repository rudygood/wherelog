import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final svc = SettingsService();
  String theme = 'system';
  List<String> tabOrder = ['Storage Items', 'Home Inventory', 'Places of Interest'];
  bool confirmDelete = true;
  bool _isReordering = false;
  int _pressedIndex = -1;

  static const List<String> kTabDisplayNames = [
    'Storage Items',
    'Home Inventory',
    'Places of Interest',
  ];

  static const Map<String, String> _legacyToDisplay = {
    'Storage': 'Storage Items',
    'Inventory': 'Home Inventory',
    'POI': 'Places of Interest',
    'Storage Items': 'Storage Items',
    'Home Inventory': 'Home Inventory',
    'Places of Interest': 'Places of Interest',
  };

  List<String> _normalize(List<String> raw) {
    if (raw.length != 3) return List<String>.from(kTabDisplayNames);
    final mapped = raw.map((e) => _legacyToDisplay[e.trim()] ?? e).toList();
    final validSet = kTabDisplayNames.toSet();
    if (mapped.every((e) => validSet.contains(e)) && mapped.toSet().length == 3) {
      return mapped;
    }
    return List<String>.from(kTabDisplayNames);
  }

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    theme = await svc.getTheme();
    final stored = await svc.getTabOrder();
    tabOrder = _normalize(stored);
    confirmDelete = await svc.getConfirmDelete();
    setState(() {});
  }

  // Dark mode (2026-11-12): persist the choice AND tell the app, so the
  // theme changes the moment the button is tapped.
  void _setTheme(String v) {
    setState(() => theme = v);
    svc.setTheme(v);
    AppTheme.modeNotifier.value = AppTheme.modeFromString(v);
  }

  Widget _buildThemeButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: selected ? AppButton.primarySmall : AppButton.secondarySmall,
        child: Text(label),
      ),
    );
  }

  Widget _buildReorderableArea() {
    Widget buildBox(String label, int idx, bool showDragHandle) {
      final isPressed = _pressedIndex == idx;
      // The boxes imitate the main page's tab tops (evaluation fix
      // E7): the name broken into two lines where the tab breaks
      // (before the last word), one fixed box width sized for the
      // widest name, and the drag handle OUTSIDE the box — a tab
      // top holds nothing but its name.
      final twoLine = label.replaceFirstMapped(
          RegExp(r' (\S+)$'), (m) => '\n${m[1]}');
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            child: Text('${idx + 1}', style: AppText.input),
          ),
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 96,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppBorder.radius),
              border: Border.all(color: isPressed ? AppColors.buttonBg : AppColors.border, width: isPressed ? 1.4 : AppBorder.width),
              boxShadow: isPressed
                  ? [BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
            ),
            transform: isPressed ? (Matrix4.identity()..translate(0.0, -1.5, 0.0)..scale(1.02)) : Matrix4.identity(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(twoLine, style: AppText.input, textAlign: TextAlign.center),
            ),
          ),
          if (showDragHandle) ...[
            const SizedBox(width: 6),
             Icon(Icons.drag_handle_rounded, size: 20, color: AppColors.textSecondary),
          ],
        ],
      );
    }

    if (_isReordering) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeOut.transform(animation.value);
              return Transform.scale(
                scale: 1.0 + (t * 0.05),
                child: Material(
                  elevation: 12 + (t * 8),
                  shadowColor: AppColors.shadowMedium,
                  borderRadius: BorderRadius.circular(AppBorder.radius),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        itemCount: tabOrder.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = tabOrder.removeAt(oldIndex);
            tabOrder.insert(newIndex, item);
            _pressedIndex = -1;
          });
          svc.setTabOrder(tabOrder);
        },
        itemBuilder: (context, index) {
          final label = tabOrder[index];
          return Padding(
            key: ValueKey(label),
            padding: const EdgeInsets.only(bottom: 8),
            child: Listener(
              onPointerDown: (_) => setState(() => _pressedIndex = index),
              onPointerUp: (_) => setState(() => _pressedIndex = -1),
              onPointerCancel: (_) => setState(() => _pressedIndex = -1),
              child: ReorderableDragStartListener(
                index: index,
                child: buildBox(label, index, true),
              ),
            ),
          );
        },
      );
    } else {
      return Column(
        children: tabOrder.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          return Padding(
            key: ValueKey(label),
            padding: const EdgeInsets.only(bottom: 8),
            child: buildBox(label, idx, false),
          );
        }).toList(),
      );
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(screenName: 'App Settings'),
      backgroundColor: AppColors.scaffold,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
           Text('DISPLAY MODE', style: AppText.dialogSection),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            children: [
              _buildThemeButton(label: 'System', selected: theme=='system', onTap: () => _setTheme('system')),
              _buildThemeButton(label: 'Light', selected: theme=='light', onTap: () => _setTheme('light')),
              _buildThemeButton(label: 'Dark', selected: theme=='dark', onTap: () => _setTheme('dark')),
            ],
          ),

          AppDivider.horizontal,

           Text('MAIN SCREEN TAB ORDER', style: AppText.dialogSection),
          const SizedBox(height: 4),
           Text('Tap "Reorder" and then drag the tabs to your desired order.', style: AppText.dialog),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: _buildReorderableArea(),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _isReordering = !_isReordering);
                    if (!_isReordering) {
                      svc.setTabOrder(tabOrder);
                    }
                  },
                  style: _isReordering ? AppButton.whiteSmall : AppButton.primarySmall,
                  child: Text(_isReordering ? 'Done' : 'Reorder'),
                ),
              ),
            ],
          ),

          AppDivider.horizontal,

          SwitchListTile(
            title:  Text('CONFIRM DELETES', style: AppText.dialogSection),
            subtitle:  Text('Ask for confirmation before deleting information', style: AppText.dialog),
            value: confirmDelete,
            activeColor: AppColors.white,
            activeTrackColor: AppColors.buttonBg,
            inactiveThumbColor: AppColors.white,
            inactiveTrackColor: AppColors.border,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) async {
              if (!v) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
                    title:  Text('Turn off delete confirmation?', style: AppText.dialogTitle),
                    content:  Text('If off, items are deleted immediately with no undo.', style: AppText.dialogAlert),
                    actions: [
                      TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: ()=>Navigator.pop(context,true), style: AppButton.primary, child: const Text('Turn Off Anyway')),
                    ],
                  ),
                );
                if (ok != true) return;
              }
              setState(()=>confirmDelete=v);
              svc.setConfirmDelete(v);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
