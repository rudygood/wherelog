import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'about_screen.dart';

/// Contact / Support — the menu tile's page ("Feedback, report issue").
/// Primarily an email page: one address, one button, and the version
/// prefilled so a report arrives with the one fact support always
/// needs first.
///
/// The address is support@wherelog.app (Rudy, 2026-11-12) — a
/// placeholder until he acquires the wherelog.app domain and sets up
/// mail for it; the address will not receive mail until then. Nothing
/// on this page says that to the user: the page is written as if the
/// address is live, because it will be by the time the app ships.
///
/// No mail account, no problem: the address is shown as copyable text
/// beside the button, and if the mail app cannot be opened the user is
/// told to copy the address instead of watching a silent failure.
/// Nothing is sent from the app except what the user writes, plus the
/// app version in the email's subject and opening line.
class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

  static const String supportEmail = 'support@wherelog.app';

  Future<void> _emailSupport(BuildContext context) async {
    // Build the query by hand with encodeComponent: queryParameters encodes
    // spaces as '+', which Outlook shows literally in the composed email.
    // encodeComponent uses %20, which every mail app decodes back to a space.
    final subject = 'WhereLog Support — ${AboutScreen.versionLabel}';
    final body = '${AboutScreen.versionLabel}\n\n';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No mail app is set up on this device. Copy the address above and send your message from another mail app.',
        ),
      ),
    );
  }

  Future<void> _copyAddress(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email address copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Contact / Support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact / Support', style: AppText.dialogTitle),
            const SizedBox(height: 4),
            Text(
              'Questions, feedback, or a problem to report — we would like to hear it.',
              style: AppText.dialog,
            ),
            const SizedBox(height: 20),
            Text('EMAIL', style: AppText.dialogSection),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(supportEmail, style: AppText.dialogItem),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Copy email address',
                  onPressed: () => _copyAddress(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppButton.primary,
                onPressed: () => _emailSupport(context),
                child: Text('Email Support', style: AppText.buttonPrimary),
              ),
            ),
            const SizedBox(height: 20),
            Text('WHAT HELPS', style: AppText.dialogSection),
            const SizedBox(height: 4),
            Text(
              'What you were doing, what happened, and what you expected. '
              'The app version is already in the email — that is usually the first thing asked for.',
              style: AppText.dialog,
            ),
            const SizedBox(height: 20),
            Text('PRIVACY', style: AppText.dialogSection),
            const SizedBox(height: 4),
            Text(
              'Your email contains only what you write, plus the app version shown below. Nothing else is sent from the app.',
              style: AppText.dialog,
            ),
            const SizedBox(height: 20),
            Text('VERSION', style: AppText.dialogSection),
            const SizedBox(height: 4),
            Text(AboutScreen.versionLabel, style: AppText.dialogItem),
          ],
        ),
      ),
    );
  }
}
