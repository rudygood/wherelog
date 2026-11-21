import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/data_transfer.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'db_inspector_screen.dart';
import 'privacy_screen.dart';

/// About — rebuilt 2026-11-17 (build 54): the splash identity scaled
/// down (app icon, slogan, wordmark), Created by SolutionWise with
/// the product-page link right after it, version and build info, a
/// Privacy Policy link (the menu tile is gone), map credits, a
/// Licenses link, and the copyright last. The visible data paths are
/// gone. Sized to fit one phone screen — the scroll view is only a
/// safety net.
///
/// Hidden in plain sight: the version row is the door to the
/// read-only database inspector — five taps, or one long-press.
/// Deliberately no visible hint; it is a diagnostic for whoever
/// maintains the app.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  /// The app version mirrors pubspec.yaml's version line; bump
  /// both together. Hand-maintained (not read from the package at
  /// runtime) so the value on screen is exactly the value in the
  /// built code — that is the whole point of the stamp: proving
  /// which build is installed.
  static const String appVersion = '1.0.0';
  static const String appBuild = '75';

  /// One string, one source of truth: the stamp shown in About
  /// and at the top of the share diagnostic report.
  static const String versionLabel = 'WhereLog $appVersion (build $appBuild)';

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int _versionTaps = 0;

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

  Future<void> _openProductPage() async {
    final uri = Uri.parse('https://solutionwise.org/wherelog');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the product page.')),
    );
  }

  void _openPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyScreen()),
    );
  }

  void _openLicenses() {
    showLicensePage(context: context);
  }

  Widget _row(String label, String value) {
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
            child: Text(value, style: AppText.dialogItem),
          ),
        ],
      ),
    );
  }

  Widget _linkRow({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: AppText.dialogItem),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Splash identity, scaled down: app icon, slogan, wordmark.
            Image.asset(
              'assets/icon/app_icon.png',
              width: 96,
              height: 96,
              errorBuilder: (c, e, s) => Icon(
                Icons.inventory_2,
                size: 64,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Where are your things?\nKeep track of them with',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.25,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
                children: [
                  TextSpan(
                    text: 'Where',
                    style: AppText.logoWhere.copyWith(fontSize: 28),
                  ),
                  TextSpan(
                    text: 'Log',
                    style: AppText.logoLogAlert.copyWith(fontSize: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Created by SolutionWise.
            Text('Created by:', style: AppText.dialog),
            const SizedBox(height: 4),
            Image.asset(
              'assets/icon/solutionwise_icon_mobile_apps.PNG',
              width: 200,
              errorBuilder: (c, e, s) => Text(
                'SolutionWise Mobile Apps',
                style: AppText.dialogItem,
              ),
            ),
            const SizedBox(height: 8),
            // Product page link, right after the attribution.
            TextButton(
              onPressed: _openProductPage,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Visit the WhereLog product page',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            // Version and build information.
            Align(
              alignment: Alignment.centerLeft,
              child: Text('VERSION', style: AppText.dialogSection),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _countVersionTap,
              onLongPress: _openInspector,
              child: _row('App version', '${AboutScreen.appVersion} (build ${AboutScreen.appBuild})'),
            ),
            _row('Database schema', 'Version ${AppDatabase.schemaVersion}'),
            _row('Backup format', 'Version ${DataTransfer.backupFormatVersion}'),
            const SizedBox(height: 16),
            // Privacy Policy link.
            _linkRow(label: 'Privacy Policy', onTap: _openPrivacy),
            const SizedBox(height: 12),
            // Map credits.
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Maps © OpenStreetMap contributors\nSatellite imagery © Esri, Maxar, Earthstar Geographics',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Open source licenses.
            _linkRow(label: 'Open Source Licenses', onTap: _openLicenses),
            const SizedBox(height: 20),
            // Copyright, last.
            Text(
              '© 2026 SolutionWise Mobile Apps. All rights reserved.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
