import 'package:flutter/material.dart';

import '../data/data_transfer.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Read-only viewer for a selected backup: what the Export/Import
/// screen's View action opens. It reads the very document a restore
/// would load — never a translation of it — and never touches the
/// database. Evaluation is an aid for whoever wants it; nothing in
/// the restore flow requires passing through here.
class BackupViewerScreen extends StatefulWidget {
  final BackupSelection selection;

  const BackupViewerScreen({super.key, required this.selection});

  @override
  State<BackupViewerScreen> createState() => _BackupViewerScreenState();
}

class _BackupViewerScreenState extends State<BackupViewerScreen> {
  DataCounts? _current;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final c = await DataTransfer.instance.currentCounts();
    if (!mounted) return;
    setState(() => _current = c);
  }

  BackupSelection get _sel => widget.selection;

  Map<int, String> _names(String section) => {
        for (final r in _sel.rows(section))
          (r['id'] as int): (r['name'] as String),
      };

  String _money(int? cents) {
    if (cents == null) return '—';
    final neg = cents < 0;
    final abs = cents.abs();
    final dollars = (abs ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < dollars.length; i++) {
      if (i > 0 && (dollars.length - i) % 3 == 0) buf.write(',');
      buf.write(dollars[i]);
    }
    return '${neg ? '-' : ''}\$$buf.${(abs % 100).toString().padLeft(2, '0')}';
  }

  String _exportedLabel() {
    final dt = _sel.exportedAt?.toLocal();
    if (dt == null) return 'Unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    var hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}, $hour:$min $ampm';
  }

  Widget _compareRow(String label, int inBackup, int? inCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(label, style: AppText.dialog)),
          Expanded(
            child: Text(
              inCurrent == null
                  ? '$inBackup'
                  : '$inBackup in backup · $inCurrent current',
              style: AppText.dialogItem,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<Map<String, dynamic>> rows,
    String Function(Map<String, dynamic>) titleOf,
    String? Function(Map<String, dynamic>) subtitleOf,
  ) {
    return ExpansionTile(
      title: Text('$title (${rows.length})', style: AppText.dialogSection),
      children: rows.isEmpty
          ?  [
              ListTile(
                dense: true,
                title: Text('None', style: AppText.dialog),
              ),
            ]
          : rows
              .map(
                (r) => ListTile(
                  dense: true,
                  title: Text(titleOf(r), style: AppText.dialogItem),
                  subtitle: subtitleOf(r) == null
                      ? null
                      : Text(subtitleOf(r)!, style: AppText.dialog),
                ),
              )
              .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genNames = _names('generals');
    final sSpecNames = _names('storageSpecifics');
    final iSpecNames = _names('inventorySpecifics');

    String locationLine(
      Map<String, dynamic> r,
      Map<int, String> specNames,
    ) {
      final g = genNames[r['general_id']] ?? '?';
      final sid = r['specific_id'];
      if (sid is int && specNames.containsKey(sid)) {
        return '$g · ${specNames[sid]}';
      }
      return g;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'View Backup'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppBorder.radius),
              border: Border.all(color: AppColors.border, width: AppBorder.width),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sel.fileName, style: AppText.dialogItem),
                const SizedBox(height: 6),
                Text('Exported: ${_exportedLabel()}', style: AppText.dialog),
                Text(
                  'Format version ${_sel.formatVersion}',
                  style: AppText.dialog,
                ),
                const SizedBox(height: 10),
                _compareRow('General Location', _sel.countOf('generals'), _current?.generals),
                _compareRow('Storage Specific', _sel.countOf('storageSpecifics'), _current?.storageSpecifics),
                _compareRow('Inventory Specific', _sel.countOf('inventorySpecifics'), _current?.inventorySpecifics),
                _compareRow('Storage Item', _sel.countOf('storageItems'), _current?.storageItems),
                _compareRow('Home Inventory', _sel.countOf('inventoryItems'), _current?.inventoryItems),
                _compareRow('Place of Interest', _sel.countOf('poiItems'), _current?.poiItems),
                _compareRow('Photos in backup', _sel.photoCount, _current?.imagesLinked),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            'General Locations',
            _sel.rows('generals'),
            (r) => r['name'] as String,
            (_) => null,
          ),
          _section(
            'Storage Specific Locations',
            _sel.rows('storageSpecifics'),
            (r) => r['name'] as String,
            (r) => 'in ${genNames[r['general_id']] ?? '?'}',
          ),
          _section(
            'Inventory Specific Locations',
            _sel.rows('inventorySpecifics'),
            (r) => r['name'] as String,
            (r) => 'in ${genNames[r['general_id']] ?? '?'}',
          ),
          _section(
            'Storage Items',
            _sel.rows('storageItems'),
            (r) => r['name'] as String,
            (r) {
              final parts = <String>[locationLine(r, sSpecNames)];
              parts.add('Qty ${r['quantity']}');
              if (r['value_cents'] != null) {
                parts.add('Value ${_money(r['value_cents'] as int)}');
              }
              if (r['photo_filename'] != null) parts.add('Photo');
              return parts.join(' · ');
            },
          ),
          _section(
            'Home Inventory',
            _sel.rows('inventoryItems'),
            (r) => r['name'] as String,
            (r) {
              final parts = <String>[];
              final brandModel = [
                if (r['brand'] != null) r['brand'] as String,
                if (r['model'] != null) r['model'] as String,
              ].join(' ');
              if (brandModel.isNotEmpty) parts.add(brandModel);
              if (r['serial_number'] != null) {
                parts.add('SN ${r['serial_number']}');
              }
              parts.add(locationLine(r, iSpecNames));
              parts.add('Qty ${r['quantity']}');
              if (r['purchase_price_cents'] != null) {
                parts.add('Purchased ${_money(r['purchase_price_cents'] as int)}');
              }
              if (r['value_cents'] != null) {
                parts.add('Replacement ${_money(r['value_cents'] as int)}');
              }
              if (r['photo_filename'] != null) parts.add('Photo');
              return parts.join(' · ');
            },
          ),
          _section(
            'Places of Interest',
            _sel.rows('poiItems'),
            (r) => r['name'] as String,
            (r) {
              final address = (r['address'] as String).trim();
              if (address.isNotEmpty) return address;
              final lat = (r['latitude'] as num).toStringAsFixed(5);
              final lng = (r['longitude'] as num).toStringAsFixed(5);
              return '$lat, $lng';
            },
          ),
        ],
      ),
    );
  }
}
