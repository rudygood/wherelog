import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../wherelog_repository.dart';
import '../widgets/app_header.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({super.key});
  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  final _repo = WhereLogRepository();
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;
  bool _showCounts = false;
  String _status = '';
  String _lastExportPath = '';

  String _exportDirPath = '';
  String _importDirPath = '';
  bool _loadingPrefs = true;

  static const _kExportDirKey = 'export_dir_path';
  static const _kImportDirKey = 'import_dir_path';

  int _cStorageItems = 0;
  int _cInventoryItems = 0;
  int _cPoiItems = 0;
  int _cGenerals = 0;
  int _cStorageSpecifics = 0;
  int _cInventorySpecifics = 0;
  int _cImages = 0;

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  @override
  void initState() {
    super.initState();
    _loadDirPrefsAndCounts();
  }

  Future<void> _loadDirPrefsAndCounts() async {
    try {
      final doc = await getApplicationDocumentsDirectory();
      final defaultExportDir = '${doc.path}/WhereLog/Exports'.replaceAll('/', '\\');
      final prefs = await SharedPreferences.getInstance();
      final savedExport = prefs.getString(_kExportDirKey);
      final savedImport = prefs.getString(_kImportDirKey);
      await _repo.load();
      _refreshCounts();
      setState(() {
        _exportDirPath = savedExport ?? defaultExportDir;
        _importDirPath = savedImport ?? defaultExportDir;
        _loadingPrefs = false;
      });
      final expDir = Directory(_exportDirPath);
      if (!await expDir.exists()) await expDir.create(recursive: true);
    } catch (_) {
      setState(() => _loadingPrefs = false);
    }
  }

  void _refreshCounts() {
    int countImages() {
      final Set<String> paths = {};
      for (var m in _repo.storageItems) {
        final ph = m['photo'] ?? m['photoPath'];
        if (ph is String && ph.isNotEmpty) {
          try { if (File(ph).existsSync()) paths.add(ph); } catch (_) {}
        }
      }
      for (var m in _repo.inventoryItems) {
        final ph = m['photo'] ?? m['photoPath'];
        if (ph is String && ph.isNotEmpty) {
          try { if (File(ph).existsSync()) paths.add(ph); } catch (_) {}
        }
      }
      for (var m in _repo.poiItems) {
        final ph = m['photo'] ?? m['photoPath'];
        if (ph is String && ph.isNotEmpty) {
          try { if (File(ph).existsSync()) paths.add(ph); } catch (_) {}
        }
      }
      return paths.length;
    }
    _cStorageItems = _repo.storageItems.length;
    _cInventoryItems = _repo.inventoryItems.length;
    _cPoiItems = _repo.poiItems.length;
    _cGenerals = _repo.generals.length;
    _cStorageSpecifics = _repo.storageSpecifics.where((s) => (s['name']?.toString() ?? '').trim().isNotEmpty).length;
    _cInventorySpecifics = _repo.inventorySpecifics.where((s) => (s['name']?.toString() ?? '').trim().isNotEmpty).length;
    _cImages = countImages();
  }

  Future<void> _saveExportDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kExportDirKey, path);
    setState(() => _exportDirPath = path);
  }

  Future<void> _saveImportDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kImportDirKey, path);
    setState(() => _importDirPath = path);
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

  Future<void> _pickExportDir() async {
    final picked = await _safePickDirectory(initialDir: _exportDirPath, dialogTitle: 'Choose Export Folder');
    if (picked != null && picked.isNotEmpty) {
      await _saveExportDir(picked);
      try { final dir = Directory(picked); if (!await dir.exists()) await dir.create(recursive: true); } catch (_) {}
      setState(() => _status = 'Export folder set to:\n$picked');
    }
  }

  Future<void> _pickImportDir() async {
    final picked = await _safePickDirectory(initialDir: _importDirPath, dialogTitle: 'Choose Import Folder');
    if (picked != null && picked.isNotEmpty) {
      await _saveImportDir(picked);
      setState(() => _status = 'Import folder set to:\n$picked');
    }
  }

  Future<Directory> _getExportBaseDir() async {
    if (_exportDirPath.isNotEmpty) {
      final dir = Directory(_exportDirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final doc = await getApplicationDocumentsDirectory();
    final base = Directory('${doc.path}/WhereLog/Exports');
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  Future<Directory> _getPhotoStoreDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}/WhereLog/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<String> _collectPhotoPaths() {
    final Set<String> paths = {};
    for (var m in _repo.storageItems) {
      final ph = m['photo'] ?? m['photoPath'];
      if (ph is String && ph.isNotEmpty) { try { if (File(ph).existsSync()) paths.add(ph); } catch (_) {} }
    }
    for (var m in _repo.inventoryItems) {
      final ph = m['photo'] ?? m['photoPath'];
      if (ph is String && ph.isNotEmpty) { try { if (File(ph).existsSync()) paths.add(ph); } catch (_) {} }
    }
    for (var m in _repo.poiItems) {
      final ph = m['photo'] ?? m['photoPath'];
      if (ph is String && ph.isNotEmpty) { try { if (File(ph).existsSync()) paths.add(ph); } catch (_) {} }
    }
    return paths.toList();
  }

  Future<String?> _doExportZip() async {
    await _repo.load();
    final exportMap = _repo.toFullJson();
    exportMap['exportedAt'] = DateTime.now().toIso8601String();
    final photoPaths = _collectPhotoPaths();
    final archive = Archive();
    final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(exportMap));
    archive.addFile(ArchiveFile('wherelog_data.json', jsonBytes.length, jsonBytes));
    final Map<String, String> basenameToOriginal = {};
    final Map<String, int> basenameCount = {};
    for (var path in photoPaths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      String base = p.basename(path);
      if (basenameCount.containsKey(base)) {
        final count = basenameCount[base]! + 1;
        basenameCount[base] = count;
        base = '${p.withoutExtension(base)}_$count${p.extension(base)}';
      } else {
        basenameCount[base] = 1;
      }
      basenameToOriginal[base] = path;
      archive.addFile(ArchiveFile('photos/$base', bytes.length, bytes));
    }
    final manifest = {'photos': basenameToOriginal.map((k, v) => MapEntry(k, {'originalPath': v}))};
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('photos_manifest.json', manifestBytes.length, manifestBytes));
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('Failed to encode ZIP');
    final exportDir = await _getExportBaseDir();
    final fileName = 'wherelog_export_${_timestamp()}.zip';
    final outFile = File('${exportDir.path}/$fileName');
    await outFile.writeAsBytes(zipBytes);
    setState(() {
      _lastExportPath = outFile.path;
      _refreshCounts();
    });
    return outFile.path;
  }

  Future<void> _handleExportKeep() async {
    setState(() { _isExporting = true; _status = 'Exporting...'; });
    try {
      final path = await _doExportZip();
      setState(() => _status = 'Export - Keep Data complete.\nZIP: $path\nCounts unchanged: Storage $_cStorageItems, Inventory $_cInventoryItems, POI $_cPoiItems');
    } catch (e) {
      setState(() => _status = 'Export failed: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExportReset() async {
    final confirm = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
      title: Text('Confirm Export - Data Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This will EXPORT then RESET all local data:', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Text('Export to:\n$_exportDirPath', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
        SizedBox(height: 10),
        Text('After export, DELETE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        SizedBox(height: 6),
        Text('• Storage Item: $_cStorageItems records\n'
             '• Home Inventory: $_cInventoryItems records\n'
             '• Place of Interest: $_cPoiItems records\n'
             '• General Location: $_cGenerals records\n'
             '• Storage Specific Location: $_cStorageSpecifics records\n'
             '• Inventory Specific Location: $_cInventorySpecifics records\n'
             '• Images: $_cImages linked (files remain on disk but unlinked)', style: TextStyle(fontSize: 12, fontFamily: 'monospace')),
        SizedBox(height: 12),
        Text('App will start from 0 counts. Restore via Import - Overwrite.', style: TextStyle(fontSize: 11, color: Colors.red)),
      ])),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Cancel')),
        ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: Text('Yes, Export then Reset')),
      ],
    ));
    if (confirm!=true) return;
    setState(() { _isExporting = true; _isClearing = true; _status = 'Exporting before reset...'; });
    try {
      final exportPath = await _doExportZip();
      setState(() => _status = 'Export saved to $exportPath\nNow resetting all data to 0...');
      // FIX: ensure file is overwritten with empty data
      await _repo.clearAllData();
      // Force reload to confirm empty
      await _repo.forceReload();
      _refreshCounts();
      setState(() => _status = 'EXPORT - DATA RESET COMPLETE.\nBackup: $exportPath\nAll counts now 0:\nStorage $_cStorageItems, Inventory $_cInventoryItems, POI $_cPoiItems, Generals $_cGenerals\n\nRestart app or go to main - you are starting from scratch.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All data cleared - backup saved at $exportPath'), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
    } catch (e, st) {
      setState(() => _status = 'Export-Reset failed: $e\n$st');
    } finally {
      setState(() { _isExporting = false; _isClearing = false; });
    }
  }

  Future<void> _doImportOverwrite() async {
    setState(() { _isImporting = true; _status = 'Picking ZIP/JSON file...'; });
    try {
      // FIXED for file_picker 13.1.0 - no FilePickerResult, no withData, no initialDirectory, no bytes
      final List<PlatformFile>? pickedFiles = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip', 'json']);

      if (pickedFiles == null || pickedFiles.isEmpty) { setState(() => _status = 'Import cancelled'); return; }
      final picked = pickedFiles.first;
      if (picked.path == null) throw Exception('Could not read file - no path');
      Uint8List bytes = await File(picked.path!).readAsBytes();
      if (picked.path != null) { try { final dir = p.dirname(picked.path!); if (dir.isNotEmpty) await _saveImportDir(dir); } catch (_) {} }

      Map<String, dynamic> importedJson;
      Map<String, String> newPhotoPathByOldBasename = {};
      if (picked.name.toLowerCase().endsWith('.zip')) {
        final archive = ZipDecoder().decodeBytes(bytes);
        ArchiveFile? jsonFile;
        for (var f in archive.files) { if (f.name == 'wherelog_data.json' || f.name.endsWith('/wherelog_data.json')) { jsonFile = f; break; } }
        if (jsonFile == null) throw Exception('ZIP missing wherelog_data.json');
        importedJson = jsonDecode(utf8.decode(jsonFile.content as List<int>)) as Map<String, dynamic>;
        final photoStoreDir = await _getPhotoStoreDir();
        for (var f in archive.files) {
          if (f.name.startsWith('photos/') && !f.isFile) continue;
          if (f.name.startsWith('photos/') && f.name != 'photos/' && !f.name.endsWith('photos_manifest.json')) {
            final base = p.basename(f.name);
            final outPath = '${photoStoreDir.path}/$base';
            await File(outPath).writeAsBytes(f.content as List<int>);
            newPhotoPathByOldBasename[base] = outPath;
          }
        }
      } else {
        importedJson = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }

      final sCount = (importedJson['storageItems'] as List?)?.length ?? 0;
      final iCount = (importedJson['inventoryItems'] as List?)?.length ?? 0;
      final pCount = (importedJson['poiItems'] as List?)?.length ?? 0;
      final gCount = (importedJson['generals'] as List?)?.length ?? ((importedJson['storageGenerals'] as List?)?.length ?? 0) + ((importedJson['inventoryGenerals'] as List?)?.length ?? 0);

      final confirm = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(
        title: Text('Confirm Import - Overwrite', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Overwrite will DELETE current:\nStorage Item: $_cStorageItems, Home Inventory: $_cInventoryItems, Place of Interest: $_cPoiItems, General Location: $_cGenerals\n\nAnd REPLACE with ZIP:\nStorage Item: $sCount, Home Inventory: $iCount, Place of Interest: $pCount, General Location: ~$gCount, Photos: ${newPhotoPathByOldBasename.length}\n\nAuto-backup will be created first in $_exportDirPath'),
        actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: Text('Yes Overwrite'))],
      ));
      if (confirm!=true) { setState(()=>_status='Import cancelled'); return; }

      // Auto-backup current before overwrite
      try {
        final backupMap = _repo.toFullJson();
        final exportDir = await _getExportBaseDir();
        final backupFile = File('${exportDir.path}/auto_backup_before_import_${_timestamp()}.json');
        await backupFile.writeAsString(const JsonEncoder.withIndent('  ').convert(backupMap));
      } catch (_) {}

      String remapPhoto(String oldPath) { final base = p.basename(oldPath); return newPhotoPathByOldBasename[base] ?? oldPath; }

      setState(() => _status = 'Importing $sCount storage, $iCount inventory...');
      await _repo.replaceAllFromJson(importedJson, remapPhoto: remapPhoto);
      await _repo.forceReload();
      _refreshCounts();

      setState(() => _status = 'Import - Overwrite COMPLETE:\n$sCount Storage Item, $iCount Home Inventory, $pCount Place of Interest, ${newPhotoPathByOldBasename.length} photos restored.\n\nCurrent counts: Storage $_cStorageItems, Inventory $_cInventoryItems, POI $_cPoiItems, Generals $_cGenerals');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import Overwrite complete: $sCount storage, $iCount inventory')));
    } catch (e, st) {
      setState(() => _status = 'Import failed: $e\n$st');
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Widget _countRow(String label, int count) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87))),
        Text(count.toString(), style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.black87)),
      ]),
    );
  }

  Widget _actionButton({required String label, required Color color, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs) {
      return Scaffold(backgroundColor: Color(0xFFF5F3EE), appBar: AppHeader(screenName: 'Export / Import'), body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Color(0xFFF5F3EE),
      appBar: AppHeader(screenName: 'Export / Import'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(0xFFE8E0D5), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
            child: Text('Imports and Exports utilize a ZIP file that stores the apps JSON data and images for backups and transfers.', style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), fontWeight: FontWeight.w600, height: 1.3)),
          ),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('RECORD & IMAGE COUNTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black87))),
                IconButton(
                  icon: Icon(_showCounts ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: Colors.black87),
                  tooltip: _showCounts ? 'Hide record types and counts' : 'Show record types and counts',
                  onPressed: () => setState(()=>_showCounts = !_showCounts),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ]),
              if (_showCounts) ...[
                Divider(height: 14),
                _countRow('Storage Item', _cStorageItems),
                _countRow('Home Inventory', _cInventoryItems),
                _countRow('Place of Interest', _cPoiItems),
                _countRow('General Location', _cGenerals),
                _countRow('Storage Specific Location', _cStorageSpecifics),
                _countRow('Inventory Specific Location', _cInventorySpecifics),
                _countRow('Images linked', _cImages),
              ],
            ]),
          ),
          SizedBox(height: 16),
          Text('SPECIFY DIRECTORIES for IMPORT & EXPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black54)),
          SizedBox(height: 8),
          Text('Import Directory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Row(children: [
            Expanded(child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)), child: Text(_importDirPath, style: TextStyle(fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis))),
            SizedBox(width: 8),
            ElevatedButton(onPressed: _pickImportDir, style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)), child: Text('Change...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          SizedBox(height: 12),
          Text('Export Directory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Row(children: [
            Expanded(child: Container(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)), child: Text(_exportDirPath, style: TextStyle(fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis))),
            SizedBox(width: 8),
            ElevatedButton(onPressed: _pickExportDir, style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)), child: Text('Change...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          ]),
          SizedBox(height: 20),
          Text('START IMPORT OR EXPORT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.black54)),
          SizedBox(height: 10),
          // Stacked vertically - 3 buttons, Merge removed
          _actionButton(label: 'Import - Overwrite', color: Colors.red, onPressed: _isImporting ? null : _doImportOverwrite),
          SizedBox(height: 10),
          _actionButton(label: 'Export - Keep Data', color: Colors.black87, onPressed: _isExporting ? null : _handleExportKeep),
          SizedBox(height: 10),
          _actionButton(label: 'Export - Data Reset', color: Colors.red, onPressed: (_isExporting || _isClearing) ? null : _handleExportReset),
          SizedBox(height: 16),
          if (_status.isNotEmpty) Container(width: double.infinity, padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFFF0EDE8), borderRadius: BorderRadius.circular(12)), child: Text(_status, style: TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          if (_lastExportPath.isNotEmpty) ...[SizedBox(height: 8), Text('Last export:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), Text(_lastExportPath, style: TextStyle(fontSize: 10, fontFamily: 'monospace'))],
        ]),
      ),
    );
  }
}
