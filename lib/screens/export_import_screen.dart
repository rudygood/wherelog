import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import '../data/data_transfer.dart';
import '../services/directory_access_service.dart';
import '../widgets/app_header.dart';
import 'backup_viewer_screen.dart';
import 'package:file_picker/file_picker.dart';

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({super.key});
  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  final _transfer = DataTransfer.instance;
  bool _isExporting = false;
  bool _isImporting = false;
  String _status = '';
  String _lastExportPath = '';

  int _cStorageItems = 0;
  int _cInventoryItems = 0;
  int _cPoiItems = 0;
  int _cGenerals = 0;
  int _cStorageSpecifics = 0;
  int _cInventorySpecifics = 0;
  int _cImages = 0;

  /// The one picked backup, decoded and validated, shared by the
  /// viewer and the restore so the file is never re-picked (or able
  /// to change) between evaluating it and restoring it.
  BackupSelection? _selection;

  /// Whether the current selection came from the Auto-Backups
  /// list. Restoring an auto-backup creates no new auto-backup
  /// (see _restoreSelected), so the flag travels with it.
  bool _selectionIsAuto = false;

  /// Auto-backups found in the app's own folder, newest first. The
  /// newest three are kept; older ones are pruned when this list is
  /// refreshed (restore writes one, then refreshes).
  List<File> _autoBackups = [];

  bool get _busy => _isExporting || _isImporting;

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _fmtExported(BackupSelection sel) {
    final dt = sel.exportedAt?.toLocal();
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

  @override
  void initState() {
    super.initState();
    _refreshCounts();
    _refreshAutoBackups();
  }

  /// The app's own backup folder, on the shared storage — visible
  /// in Files and over USB, and creatable by the app itself. There
  /// is no standing directory setting; this folder's one job is to
  /// receive the automatic backup written before a restore. It is
  /// removed if the app is uninstalled.
  Future<String> _defaultDirPath() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return '${ext.path}/WhereLog/Exports';
    } catch (_) {}
    final doc = await getApplicationDocumentsDirectory();
    return '${doc.path}/WhereLog/Exports';
  }

  Future<void> _refreshCounts() async {
    final c = await _transfer.currentCounts();
    if (!mounted) return;
    setState(() {
      _cStorageItems = c.storageItems;
      _cInventoryItems = c.inventoryItems;
      _cPoiItems = c.poiItems;
      _cGenerals = c.generals;
      _cStorageSpecifics = c.storageSpecifics;
      _cInventorySpecifics = c.inventorySpecifics;
      _cImages = c.imagesLinked;
    });
  }

  Future<String?> _safePickDirectory({String? initialDir, String dialogTitle = 'Choose Folder'}) async {
    String? result;
    if (initialDir != null && initialDir.isNotEmpty) {
      try {
        final dir = Directory(initialDir);
        if (!await dir.exists()) await dir.create(recursive: true);
        result = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle, initialDirectory: dir.absolute.path);
      } catch (e) {
        try { result = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle); } catch (_) { result = null; }
      }
      if (result == null) {
        try { result = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle); } catch (_) {}
      }
    } else {
      try { result = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle); } catch (_) {}
    }
    return result;
  }

  Future<String> _doExportZip(Directory exportDir) async {
    final out = await _transfer.exportZipTo(exportDir);
    if (mounted) setState(() => _lastExportPath = out.path);
    await _refreshCounts();
    return out.path;
  }

  Future<void> _handleExportKeep() async {
    setState(() { _isExporting = true; _status = 'Choosing export folder...'; });
    // On iOS the folder must be picked through the native side,
    // which holds the folder's security-scoped access open until
    // the write is done; a plain path from the file picker carries
    // no permission to write. The hold is released in the finally,
    // whatever the export's outcome.
    var holdIosFolder = false;
    try {
      final String? picked;
      if (Platform.isIOS) {
        picked = await DirectoryAccessService.pickDirectory();
        holdIosFolder = picked != null && picked.isNotEmpty;
      } else {
        picked = await _safePickDirectory(dialogTitle: 'Choose Export Folder');
      }
      if (picked == null || picked.isEmpty) { setState(() => _status = 'Export cancelled'); return; }
      final dir = Directory(picked);
      if (!await dir.exists()) await dir.create(recursive: true);
      setState(() => _status = 'Exporting...');
      final path = await _doExportZip(dir);
      setState(() => _status = 'Export - Keep Data complete.\nZIP: $path\nCounts unchanged: Storage $_cStorageItems, Inventory $_cInventoryItems, POI $_cPoiItems');
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
    } finally {
      if (holdIosFolder) await DirectoryAccessService.releaseDirectory();
      setState(() => _isExporting = false);
    }
  }

  /// Classic selection: the system file picker, navigated to
  /// wherever the backup lives. On Android the plugin hands back a
  /// copy of the file from its own cache; the copy's bytes are the
  /// backup, and nothing here needs the folder the original came
  /// from, so the copy serves perfectly well.
  Future<void> _selectBackup() async {
    setState(() { _isImporting = true; _status = 'Picking backup file...'; });
    try {
      final List<PlatformFile>? pickedFiles = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip', 'json']);
      if (pickedFiles == null || pickedFiles.isEmpty) { setState(() => _status = 'Selection cancelled'); return; }
      final picked = pickedFiles.first;
      if (picked.path == null) throw Exception('Could not read file - no path');
      final bytes = await File(picked.path!).readAsBytes();
      final selection = _transfer.parseBackup(fileName: picked.name, bytes: bytes);
      setState(() {
        _selection = selection;
        _selectionIsAuto = false;
        // No status line for a selection: the Selected Backup box
        // already shows what was picked.
        _status = '';
      });
    } on FormatException catch (e) {
      setState(() {
        _selection = null;
        _status = e.message;
      });
    } catch (e) {
      setState(() {
        _selection = null;
        _status = 'Could not read that backup: $e';
      });
    } finally {
      setState(() => _isImporting = false);
    }
  }

  /// Scans the app's own folder for auto-backups, newest first,
  /// keeps the newest three, and deletes the rest — that deletion
  /// is the whole retention policy, and it runs here so it happens
  /// on page load as well as right after a restore writes a new one.
  Future<void> _refreshAutoBackups() async {
    try {
      final dir = Directory(await _defaultDirPath());
      final List<File> found = [];
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.split('/').last.startsWith('auto_backup_before_import_') && entity.path.toLowerCase().endsWith('.zip')) {
            found.add(entity);
          }
        }
      }
      final modified = <File, DateTime>{};
      for (final f in found) {
        try { modified[f] = f.statSync().modified; } catch (_) { modified[f] = DateTime.fromMillisecondsSinceEpoch(0); }
      }
      found.sort((a, b) => modified[b]!.compareTo(modified[a]!));
      for (final old in found.skip(3)) {
        try { await old.delete(); } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _autoBackups = found.take(3).toList());
    } catch (_) {}
  }

  /// Loads an auto-backup as the selection, through the same parse
  /// as a picked backup, so counts, View Backup, and Restore This
  /// Backup all work from it unchanged. The app reads its own
  /// folder directly — no system picker, which cannot be relied on
  /// to browse into an app's Android/data folder.
  Future<void> _selectAutoBackup() async {
    final chosen = await showDialog<File>(context: context, builder: (c) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
      title: const Text('Auto-Backups', style: AppText.dialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _autoBackups.length,
            itemBuilder: (context, i) {
              final f = _autoBackups[i];
              DateTime when = DateTime.fromMillisecondsSinceEpoch(0);
              String size = '';
              try {
                final st = f.statSync();
                when = st.modified;
                final kb = st.size / 1024;
                size = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(0)} KB';
              } catch (_) {}
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, size: 20, color: AppColors.textSecondary),
                title: Text(_fmtStamp(when.toLocal()), style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                subtitle: size.isEmpty ? null : Text(size, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                onTap: () => Navigator.pop(c, f),
              );
            },
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))],
    ));
    if (chosen == null) return;
    setState(() { _isImporting = true; });
    try {
      final bytes = await chosen.readAsBytes();
      final selection = _transfer.parseBackup(fileName: chosen.path.split('/').last, bytes: bytes);
      setState(() {
        _selection = selection;
        _selectionIsAuto = true;
        _status = '';
      });
    } on FormatException catch (e) {
      setState(() {
        _selection = null;
        _status = e.message;
      });
    } catch (e) {
      setState(() {
        _selection = null;
        _status = 'Could not read that auto-backup: $e';
      });
    } finally {
      setState(() => _isImporting = false);
    }
  }

  /// 'Nov 1, 2026 · 3:42 PM' — the house stamp style, for a plain
  /// date-time such as a file's modified time.
  String _fmtStamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    var hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$min $ampm';
  }

  void _viewSelected() {
    final sel = _selection;
    if (sel == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BackupViewerScreen(selection: sel)),
    );
  }

  Future<void> _restoreSelected() async {
    final sel = _selection;
    if (sel == null) return;
    final String autoNote = _selectionIsAuto
        ? 'This backup is itself an auto-backup, so no new auto-backup will be created.'
        : 'An auto-backup of the current data will be created first in the app\'s own backup folder';
    final confirm = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
      title: const Text('Confirm Restore - Overwrite', style: AppText.dialogTitleAlert),
      content: Text('Restore will DELETE current:\nStorage Item: $_cStorageItems, Home Inventory: $_cInventoryItems, Place of Interest: $_cPoiItems, General Location: $_cGenerals\n\nAnd REPLACE with this backup:\n${sel.fileName}\nExported: ${_fmtExported(sel)}\nStorage Item: ${sel.countOf('storageItems')}, Home Inventory: ${sel.countOf('inventoryItems')}, Place of Interest: ${sel.countOf('poiItems')}, General Location: ${sel.countOf('generals')}, Photos: ${sel.photoCount}\n\n$autoNote', style: const TextStyle(fontSize: 12)),
      actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: AppButton.primary.copyWith(backgroundColor: WidgetStateProperty.all(AppColors.alert)), child: const Text('Yes, Restore'))],
    ));
    if (confirm!=true) { setState(()=>_status='Restore cancelled'); return; }

    setState(() { _isImporting = true; _status = _selectionIsAuto ? 'Restoring ${sel.fileName}...' : 'Creating auto-backup of current data...'; });
    try {
      // The safety copy is written before a restore from an outside
      // backup file. Restoring an auto-backup writes none: the state
      // being replaced was itself reached by restoring and its
      // source still exists, and a fresh copy could prune the very
      // auto-backup lineage being restored from.
      File? autoBackup;
      if (!_selectionIsAuto) {
        try {
          final autoDir = Directory(await _defaultDirPath());
          if (!await autoDir.exists()) await autoDir.create(recursive: true);
          autoBackup = await _transfer.exportZipTo(autoDir, fileName: 'auto_backup_before_import_${_timestamp()}.zip');
        } catch (e) {
          setState(() => _status = 'Restore stopped: the auto-backup of current data could not be written ($e). Nothing was changed.');
          return;
        }
        setState(() => _status = 'Restoring ${sel.fileName}...');
      }
      await _transfer.restore(sel);
      await _refreshCounts();
      final autoLine = autoBackup != null ? '\nAuto-backup of previous data: ${autoBackup.path}' : '';
      setState(() => _status = 'Restore COMPLETE from ${sel.fileName}:\n${sel.countOf('storageItems')} Storage Item, ${sel.countOf('inventoryItems')} Home Inventory, ${sel.countOf('poiItems')} Place of Interest, ${sel.photoCount} photos restored.$autoLine\n\nCurrent counts: Storage $_cStorageItems, Inventory $_cInventoryItems, POI $_cPoiItems, Generals $_cGenerals');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore complete from ${sel.fileName}'), backgroundColor: AppColors.buttonBg));
    } catch (e, st) {
      setState(() => _status = 'Restore failed: $e\n$st');
    } finally {
      setState(() => _isImporting = false);
      _refreshAutoBackups();
    }
  }

  /// A bordered box whose name sits on its top border, group-box
  /// style: the label chip is as tall as twice the box's top margin,
  /// so the border line runs through the label's vertical center.
  /// [labelRight] puts the label at the upper right instead of just
  /// past the upper-left rounded corner.
  Widget _labeledBox({required String label, required Widget child, bool labelRight = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 9),
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 11),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppBorder.radius), border: Border.all(color: AppColors.border, width: AppBorder.width)),
          child: child,
        ),
        Positioned(
          left: labelRight ? null : 12,
          right: labelRight ? 12 : null,
          top: 0,
          child: Container(
            height: 18,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.scaffold,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ),
      ],
    );
  }

  void _showMoreInfo() {
    showDialog<void>(context: context, builder: (c) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
      title: const Text('More Information', style: AppText.dialogTitle),
      content: const SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Start Export asks for a folder, then writes a ZIP backup of all records and their photos into it. The file name carries the date and time it was made. There is no standing folder setting — each export asks, each time.', style: TextStyle(fontSize: 12)),
        SizedBox(height: 10),
        Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Select a Backup asks for the backup file, wherever it lives. Its record counts then appear beside the current counts below, and View Backup shows its contents before you decide. Restoring replaces all current data; a backup of the current data is written automatically first, to the app\'s own backup folder, so a restore can be undone. Restoring an auto-backup itself creates no new one. When one exists, an Auto-Backups button below the main buttons loads it directly — the newest three are kept and older ones are deleted automatically. The app\'s folder is removed if the app is uninstalled.', style: TextStyle(fontSize: 12)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ));
  }

  Widget _countHeaderRow() {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary);
    return const Padding(
      padding: EdgeInsets.only(left: 2, right: 2, bottom: 3),
      child: Row(children: [
        Expanded(child: SizedBox()),
        SizedBox(width: 56, child: Text('Current', textAlign: TextAlign.right, style: style)),
        SizedBox(width: 56, child: Text('Backup', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.alert))),
      ]),
    );
  }

  Widget _countRow(String label, int count, {int? backup}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        SizedBox(width: 56, child: Text(count.toString(), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
        SizedBox(width: 56, child: Text(backup?.toString() ?? '\u2013', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppColors.alert))),
      ]),
    );
  }

  Widget _actionButton({required String label, required Color color, required VoidCallback? onPressed}) {
    final ButtonStyle style = color == AppColors.alert
        ? AppButton.primary.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return AppColors.buttonBgDisabled;
              return AppColors.alert;
            }),
          )
        : AppButton.primary.copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return AppColors.buttonBgDisabled;
              return AppColors.buttonBg;
            }),
          );
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: style.copyWith(
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8, vertical: 0)),
          minimumSize: WidgetStateProperty.all(const Size(0, 36)),
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ),
        child: Text(label, textAlign: TextAlign.center, maxLines: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Export / Import'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 1) What this page does, in brief.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.banner, borderRadius: BorderRadius.circular(AppBorder.radius), border: Border.all(color: AppColors.border, width: AppBorder.width)),
            child: const Text('Imports and Exports utilize a ZIP file that stores the app\'s data and images for backups and transfers. Start Export asks for the folder to write to, and Select a Backup asks for the backup file to open — navigate to wherever your backups live. Before a restore replaces your data, a copy of the current database is saved inside the app. The Auto-Backups button can load that copy back to undo the restore.', style: TextStyle(fontSize: 12, color: AppColors.infoBrown, fontWeight: FontWeight.w600, height: 1.3)),
          ),
          Row(children: [
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _showMoreInfo,
              icon: const Icon(Icons.info_outline, size: 16),
              label: const Text('More Info'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),

          // 2) The two starting actions, side by side.
          Row(
            children: [
              _actionButton(label: 'Start Export', color: AppColors.buttonBg, onPressed: _busy ? null : _handleExportKeep),
              const SizedBox(width: 8),
              _actionButton(label: 'Select a Backup', color: AppColors.buttonBg, onPressed: _busy ? null : _selectBackup),
            ],
          ),

          if (_autoBackups.isNotEmpty)
            Row(children: [
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _selectAutoBackup,
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Auto-Backups'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap, textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),

          // 3) The picked backup, once there is one, with its own
          // buttons unchanged below it.
          if (_selection != null) ...[
            const SizedBox(height: 14),
            _labeledBox(
              label: 'Selected Backup',
              labelRight: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selection!.fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text('Exported: ${_fmtExported(_selection!)}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                  Text('Format version ${_selection!.formatVersion}', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 6),
                const Text('Current database record counts are shown below beside the backup record counts.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionButton(label: 'View\nBackup', color: AppColors.buttonBg, onPressed: _busy ? null : _viewSelected),
                const SizedBox(width: 8),
                _actionButton(label: 'Restore This\nBackup', color: AppColors.alert, onPressed: _busy ? null : _restoreSelected),
              ],
            ),
          ],

          const SizedBox(height: 14),
          // 4) Counts last: current beside backup, under column
          // headers, tight rows — the list is read-only.
          _labeledBox(
            label: 'Record Counts',
            child: Column(children: [
              _countHeaderRow(),
              _countRow('Storage Item', _cStorageItems, backup: _selection?.countOf('storageItems')),
              _countRow('Home Inventory', _cInventoryItems, backup: _selection?.countOf('inventoryItems')),
              _countRow('Place of Interest', _cPoiItems, backup: _selection?.countOf('poiItems')),
              _countRow('General Location', _cGenerals, backup: _selection?.countOf('generals')),
              _countRow('Storage Specific Location', _cStorageSpecifics, backup: _selection?.countOf('storageSpecifics')),
              _countRow('Inventory Specific Location', _cInventorySpecifics, backup: _selection?.countOf('inventorySpecifics')),
              _countRow('Images linked', _cImages, backup: _selection?.photoCount),
            ]),
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Text(_status, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textPrimary)),
            ),
          if (_lastExportPath.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Last export:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(_lastExportPath, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary)),
          ],
        ]),
      ),
    );
  }
}
