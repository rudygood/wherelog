import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/data_transfer.dart';
import '../data/photo_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'db_inspector_screen.dart';

/// About — the page the menu tile always promised ("Version, data
/// paths"). The app version mirrors pubspec.yaml's version line; bump
/// both together.
///
/// Hidden in plain sight: the version row is the door to the read-only
/// database inspector — five taps, or one long-press. Deliberately no
/// visible hint; it is a diagnostic for whoever maintains the app.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String appVersion = '1.0.0';
  static const String appBuild = '1';

  int _versionTaps = 0;
  String? _dbPath;
  String? _photosPath;

  @override
  void initState() {
    super.initState();
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final dbPath = await AppDatabase.instance.databasePath();
    final photosDir = await PhotoStore.photosDir();
    if (!mounted) return;
    setState(() {
      _dbPath = dbPath;
      _photosPath = photosDir.path;
    });
  }

  void _openInspector() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DbInspectorScreen()),
    );
  }

  void _countVersionTap() {
    _versionTaps++;
    if (_versionTaps >= 5) {
      _versionTaps = 0;
      _openInspector();
    }
  }

  Widget _row(String label, String value, {bool selectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppText.dialog),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: AppText.dialogItem)
                : Text(value, style: AppText.dialogItem),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'About'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WhereLog', style: AppText.dialogTitle),
            const SizedBox(height: 4),
            const Text(
              'Storage items, home inventory, and places of interest.',
              style: AppText.dialog,
            ),
            const SizedBox(height: 20),
            const Text('VERSION', style: AppText.dialogSection),
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _countVersionTap,
              onLongPress: _openInspector,
              child: _row('App version', '$appVersion (build $appBuild)'),
            ),
            _row('Database schema', 'Version ${AppDatabase.schemaVersion}'),
            _row('Backup format', 'Version ${DataTransfer.backupFormatVersion}'),
            const SizedBox(height: 16),
            const Text('DATA PATHS', style: AppText.dialogSection),
            const SizedBox(height: 4),
            _row('Database', _dbPath ?? '…', selectable: true),
            _row('Photos', _photosPath ?? '…', selectable: true),
          ],
        ),
      ),
    );
  }
}
