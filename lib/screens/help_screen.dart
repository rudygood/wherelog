import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Help page (2026-11-13, first draft): a how-to guide for WhereLog.
/// Written to be read top to bottom once, then dipped into by
/// section. Rudy reviews it and the sections grow or shrink from
/// his feedback — this is a start, not the final word.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
      appBar: const AppHeader(screenName: 'Help'),
      backgroundColor: AppColors.scaffold,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Text(
            'WhereLog keeps track of three kinds of things: what you have stored, '
            'what you own at home, and places you want to find again. Everything '
            'lives on your device; backups and reports are how it leaves the app.',
            style: AppText.dialog,
          ),
          AppDivider.horizontal,
          _section(
            'THE THREE TABS',
            'Storage Items: things put away in boxes, bins, and sheds — where they are, so you can find them again.\n'
            'Home Inventory: what you own at home, with values — the basis for the insurance report.\n'
            'Places of Interest: spots on the map — trailheads, overlooks, rural places with no street address, or any address you want to return to.',
          ),
          AppDivider.horizontal,
          _section(
            'ADDING A STORAGE OR INVENTORY ITEM',
            'Tap + Add on the tab. Fill in the name, then the location: the location field shows your current General and Specific — tap it to change it, tap + to add a new location on the spot.\n'
            'You can also add brand, model, serial number, acquisition date, quantity, purchase price, replacement value, notes, and a photo — take one, choose from the gallery, or paste one from the clipboard.\n'
            'Tap + Add Item. The location stays put after each add, so you can enter several items in the same place without re-picking it; the list under Added This Session shows what went in.',
          ),
          AppDivider.horizontal,
          _section(
            'LOCATIONS',
            'Every Storage and Home Inventory item has a General location (a room, a building, a property) and may also have a Specific location (a shelf, a closet, a box). One shared list of Generals serves both tabs; each tab has its own Specifics under each General.\n'
            'Manage them all on the Location Options page (menu > Location Options). Each General is a card you can expand: Storage Specifics run on blue lines, Inventory Specifics on red. Add a new General with the entry field at the bottom of the screen; new Specifics are added in the last row of each color\u2019s list.\n'
            'Tap any entry to rename it or delete it — delete is not offered while items still use that location. The pencil switch at the top turns the page read-only, hiding all the add controls.',
          ),
          AppDivider.horizontal,
          _section(
            'PLACES OF INTEREST',
            'Three ways to add a place:\n'
            '• Share it: in your maps app (or from a contact\u2019s address), share to WhereLog. It lands in the import queue — tap the green check to import it, or the X to drop it.\n'
            '• Paste it: tap Paste from Clipboard and paste a Maps link, a geo: link, or plain latitude and longitude.\n'
            '• Import a GPX file: tap Import GPX File and pick a .gpx file; its waypoints come in as places.\n'
            'After import, check the pin: if it isn\u2019t on the right spot, zoom in and tap the right spot to move it. The map view shows places around you (25 miles by default); Directions opens your maps app for the drive.',
          ),
          AppDivider.horizontal,
          _section(
            'FINDING THINGS',
            'Each tab has a search box at the top, a filter button (the tune icon) to narrow the list, and a sort control to choose the order. On Places of Interest, the map button switches between the list and the map.',
          ),
          AppDivider.horizontal,
          _section(
            'BACKING UP & RESTORING',
            'Menu > Export / Import makes a ZIP backup with everything — items, locations, places, and photos — and restores it. Each export asks you to choose a folder; each restore asks you to pick the backup file, and only the red Restore This Backup button actually restores. Before restoring, the app saves an automatic backup of what you have now and keeps the newest three.',
          ),
          AppDivider.horizontal,
          _section(
            'REPORTS',
            'Menu > Reports has two things: the Home Inventory Report, a print-ready PDF for insurance records — it opens as a preview you can print or share to Files — and the three location lists as spreadsheet (CSV) files, so your location data is never locked inside the app.',
          ),
          AppDivider.horizontal,
          _section(
            'SETTINGS',
            'Menu > Settings: Display Mode (System, Light, or Dark); Main Screen Tab Order (drag the tabs left or right to reorder them); and Confirm Deletes (ask before deleting — turning it off asks you to confirm once, and then deletes happen immediately).',
          ),
          AppDivider.horizontal,
          _section(
            'GETTING HELP',
            'If something goes wrong, Menu > Contact / Support sends an email to the developer. Menu > About shows the version, the database and photo locations, and — behind a long-press on the version row — a database inspector.\n'
            'If a share into WhereLog misbehaves, long-press the WhereLog title on the main screen for a copyable diagnostics report to send with your message.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
