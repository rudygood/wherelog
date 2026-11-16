import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Privacy Policy page (2026-11-15, build 23): the same policy as
/// the SolutionWise website (solutionwise.org/wherelog-privacy).
/// The website copy is the master — this in-app copy mirrors it,
/// so the policy is readable offline, and it changes only when
/// the website policy changes.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Widget _section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.dialogSection),
        const SizedBox(height: 4),
        Text(body, style: AppText.dialog),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(screenName: 'Privacy Policy'),
      backgroundColor: AppColors.scaffold,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Text(
            'Effective: November 14, 2026\nWhereLog is made by SolutionWise.',
            style: AppText.dialog,
          ),
          AppDivider.horizontal,
          Text(
            'The short version: WhereLog keeps your information on your own device. '
            'It does not send your items, locations, photos, or notes to us or to '
            'anyone else. There is no account, no advertising, and no tracking.',
            style: AppText.dialog,
          ),
          AppDivider.horizontal,
          _section(
            'WHAT WHERELOG STORES',
            'Everything you enter in WhereLog \u2014 your storage items and personal inventory, '
            'your General and Specific locations, your Places of Interest with their GPS '
            'coordinates, your photos and notes \u2014 is stored in a database on your device '
            'only. It is never uploaded to a server.',
          ),
          AppDivider.horizontal,
          _section(
            'NO ACCOUNT',
            'WhereLog has no sign-up and no sign-in. There is no password and no user '
            'account to create, so there is no account information to collect or to delete.',
          ),
          AppDivider.horizontal,
          _section(
            'NO ANALYTICS, NO ADS, NO TRACKING',
            'WhereLog contains no analytics, no advertising, and no tracking tools. We do '
            'not collect usage statistics and we do not share anything with advertisers '
            'or data brokers.',
          ),
          AppDivider.horizontal,
          _section(
            'MAPS AND ADDRESS LOOKUPS',
            'When you view a map, WhereLog fetches map images from OpenStreetMap and Esri, '
            'the same way any map app loads its tiles. Those services receive a standard web '
            'request for the map area you are viewing, including your device\u2019s internet address.\n'
            'When you add a place by typing an address, that address is sent to Nominatim, the '
            'OpenStreetMap address lookup service, so it can be turned into map coordinates. If '
            'you drop a pin instead, no address is sent anywhere.\n'
            'WhereLog uses your device\u2019s location only when you ask it to \u2014 for example, to '
            'drop a pin where you are standing or to center the map. Your location is not sent '
            'to SolutionWise.',
          ),
          AppDivider.horizontal,
          _section(
            'SHARING INTO WHERELOG',
            'When you share something to WhereLog from another app \u2014 a map link, a photo, '
            'an address \u2014 that content is saved on your device, in WhereLog, and nowhere else.',
          ),
          AppDivider.horizontal,
          _section(
            'BACKUPS, EXPORTS, AND REPORTS',
            'Backups, CSV exports, and PDF reports are files WhereLog creates on your device '
            'or in a folder you choose. Nothing is uploaded in the process. Where those files '
            'go after that is your choice.',
          ),
          AppDivider.horizontal,
          _section(
            'CONTACTING SUPPORT',
            'If you email us for help, your email address and message come to us at '
            'support@wherelog.app so we can answer you. We use it only to reply, and we do '
            'not share it.',
          ),
          AppDivider.horizontal,
          _section(
            'DELETING YOUR DATA',
            'Because everything is stored on your device, you can delete any item, location, '
            'or place inside the app at any time. Deleting the app deletes all of its data '
            'from your device.',
          ),
          AppDivider.horizontal,
          _section(
            'CHILDREN',
            'WhereLog collects no personal information from anyone, including children.',
          ),
          AppDivider.horizontal,
          _section(
            'CHANGES TO THIS POLICY',
            'If this policy changes, the new version will be posted on the SolutionWise '
            'website (solutionwise.org/wherelog-privacy), and the effective date there will '
            'be updated.',
          ),
          AppDivider.horizontal,
          _section(
            'CONTACT',
            'Questions about this policy: support@wherelog.app',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
