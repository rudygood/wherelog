import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'onboarding_screen.dart';

/// Help page (2026-11-13, first draft; rewritten from Rudy's markup
/// 2026-11-19, build 62): a how-to guide for WhereLog. Written to be
/// read top to bottom once, then dipped into by section. Rudy
/// reviews it and the sections grow or shrink from his feedback.
///
/// Excerpts (2026-11-18, build 59; detail mocks build 62): the
/// sections that show a screen carry a small excerpt of that screen,
/// rebuilt as widgets — the same excerpts the introduction tour uses,
/// shared from onboarding_screen.dart, plus a Location Options card,
/// a Reports excerpt, and — for the Additional Item Details section —
/// separate Storage and Inventory detail mocks and a photo/notes
/// mock, each true to its screen (the tour keeps the single
/// DetailChips union). They are light-locked illustrations (white
/// panel), so they read the same in dark mode.
///
/// Wordmark (2026-11-19, build 62): Rudy writes WhereLog in two
/// colours in his Help text — blue Where, red Log, matching the
/// app's wordmark. The body text renders it that way wherever the
/// name appears (see _bodyText).
///
/// Prose size (2026-11-19, build 67): the Help's own text is 13px.
/// CAUSE (found 2026-11-19, Rudy's screenshots): sections whose body
/// contains 'WhereLog' rendered smaller than sections without it.
/// _bodyText used RichText for the two-colour name, but a bare RichText
/// does not apply the ambient text scaler the way Text does — so on a
/// device with a text scale above 1.0 the RichText sections came out
/// smaller than the Text sections. Fix: Text.rich (a Text widget) so
/// both paths scale alike. Build 66's 15px bump was the wrong fix and
/// was reverted; the size stays 13px. The mock pictures keep the real
/// screens' sizes.
///
/// Contents drawer (2026-11-18, build 59): a small list button floats
/// at the lower right; tapping it — or dragging in from the right
/// edge — slides out a table of contents. Tapping a section jumps
/// straight to it.
///
/// Contents tap (2026-11-20, build 69): tapping a section sometimes
/// did nothing — Rudy, testing build 68, found a tap could fail,
/// retrying the same entry did nothing until another entry was
/// tapped, and then the failed entry worked again. Cause, verified
/// against Flutter's ScrollPosition.ensureVisible source: it clamps
/// the target offset to maxScrollExtent and returns at once when
/// target == pixels, with no animation. So a section already at its
/// final position does not move, and the last sections cannot reach
/// the top at all — there is not enough content below them to scroll
/// that far, so their target is the same maxScrollExtent whether the
/// page is already there or not. Fix: a full-viewport spacer at the
/// end of the list (see below), so every section, including the
/// last, has enough content below it to reach the top. The jump
/// itself is unchanged.
///
/// Contents tap (2026-11-20, build 70): build 69 did NOT fix it.
/// Rudy, testing build 69, found the pattern: tapping a heading
/// that is not displayed on the page does nothing; only headings
/// already displayed somewhere on the page reposition (to the top).
/// Cause: the body was a ListView, whose children are built LAZILY
/// — a section off-screen has not been built yet, so its GlobalKey
/// has no BuildContext (currentContext is null) and _jumpTo's null
/// guard silently skips the scroll. That also explains the earlier
/// "sticky" pattern: a failed tap stays failed until another tap
/// moves the page and brings the section into view. Fix: the body
/// is now a SingleChildScrollView with a Column, which builds ALL
/// sections eagerly, so every section's key always has a context
/// and _jumpTo works for every entry. The build-69 bottom spacer
/// stays — the last sections still need it to reach the top.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final ScrollController _scrollController = ScrollController();

  /// One key per section, in the order they appear. The contents
  /// drawer jumps to a section through its key.
  final List<GlobalKey> _sectionKeys =
      List.generate(_sectionTitles.length, (_) => GlobalKey());

  static const List<String> _sectionTitles = [
    'WHAT IS WHERELOG?',
    'MAIN PAGE - THREE TABS',
    'USE IT YOUR WAY',
    'ADDING A STORAGE OR INVENTORY ITEM',
    'ADDITIONAL ITEM DETAILS',
    'LOCATIONS',
    'PLACES OF INTEREST',
    'FINDING THINGS',
    'DELETING OR MOVING ENTRIES',
    'BACKING UP & RESTORING',
    'REPORTS',
    'SETTINGS',
    'GETTING HELP',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Close the contents drawer, then scroll the tapped section to
  /// the top of the view. Scrollable.ensureVisible clamps the
  /// target to maxScrollExtent and does nothing when the section is
  /// already there (see the header note) — the bottom spacer below
  /// is what makes the last sections able to reach the top at all.
  /// Every section is built eagerly (SingleChildScrollView + Column,
  /// build 70), so the key's context always exists; a null target
  /// would mean a section that is not on the page at all.
  void _jumpTo(int index) {
    final target = _sectionKeys[index].currentContext;
    Navigator.of(context).pop();
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  /// A section: its title, an optional excerpt of the screen it
  /// describes, then the how-to text. A section may also carry a
  /// second excerpt ([excerpt2]) with further text ([body2]) after
  /// it, so its graphics can be separated by text instead of all
  /// stacking at the top (Additional Item Details does this).
  /// A section. [subtitle] is an optional second header line under the
  /// title — used where the section explains a menu function by another
  /// name, so the reader connects the two (build 74: BACKING UP &
  /// RESTORING carries "Export / Import" under it).
  Widget _section(int index, String body,
      {Widget? excerpt, Widget? excerpt2, String? body2, String? subtitle}) {
    return Container(
      key: _sectionKeys[index],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_sectionTitles[index],
              style: AppText.dialogSection.copyWith(fontSize: 13)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppText.dialog
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 4),
          if (excerpt != null) ...[
            _excerptPanel(excerpt),
            const SizedBox(height: 8),
          ],
          _bodyText(body),
          if (excerpt2 != null) ...[
            const SizedBox(height: 8),
            _excerptPanel(excerpt2),
            const SizedBox(height: 8),
            if (body2 != null) _bodyText(body2),
          ],
        ],
      ),
    );
  }

  /// The body text, with the WhereLog name in its two colours —
  /// blue Where, red Log — wherever it appears, as Rudy writes it.
  Widget _bodyText(String body) {
    final parts = body.split('WhereLog');
    final style = AppText.dialog.copyWith(fontSize: 13);
    if (parts.length == 1) {
      return Text(body, style: style);
    }
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: 'Where',
          style: TextStyle(color: AppColors.logoBlue),
        ));
        spans.add(TextSpan(
          text: 'Log',
          style: TextStyle(color: AppColors.alert),
        ));
      }
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }

  /// The white panel an excerpt sits in. The excerpts are
  /// light-locked, so the panel is white in both modes — the mock
  /// reads exactly as it does in the introduction tour.
  Widget _excerptPanel(Widget excerpt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppBorder.radius),
      ),
      child: excerpt,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(screenName: 'Help'),
      backgroundColor: AppColors.scaffold,
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Text('Contents',
                  style: AppText.dialogSection.copyWith(fontSize: 13)),
              const SizedBox(height: 8),
              for (int i = 0; i < _sectionTitles.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_sectionTitles[i],
                      style: AppText.dialog.copyWith(fontSize: 13)),
                  onTap: () => _jumpTo(i),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton.small(
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          tooltip: 'Contents',
          child: const Icon(Icons.list),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _section(
            0,
            'WhereLog began as an app to remember where things were stored. Lots of people can use help finding things that are hidden away in boxes and bins. Mobile devices that are always close at hand are a great way to keep a log of where your things are located. But the app grew to log where three different types of things are located.\n'
            'Everything lives on your device; backups and reports are how it leaves the app.',
          ),
          AppDivider.horizontal,
          _section(
            1,
            'The WhereLog main page has three tabs. Each tab contains a log of items and their location. The Storage Items log lists the location of items you have stored. The Inventory Items log contains a list of your assets. The Places of Interest tab is a log of GPS coordinates for places you want to be able to find again even if they do not have an address.\n'
            'When you need to locate an item or place you will do it from this main page. You can search for an item on any of the three tabs, and filter and sort the list — see Finding Things below for how.',
            excerpt: const TabBarMock(),
          ),
          AppDivider.horizontal,
          _section(
            2,
            'WhereLog\u2019s design accommodates different types of users. Some may not want to track all three types of information. You can arrange the main page tab order in Settings to match your own preference. You can reorder the tabs, but every tab stays on the page — there is no way to turn one off.\n'
            'The app allows users to log items with only a name and location if this minimal information is all they need. You can also add more details for each item.',
          ),
          AppDivider.horizontal,
          _section(
            3,
            'Tap the + Add button at the bottom of the tab to open the Add screen. Enter the location and the name. When you add the location and name for the item they are automatically displayed as a unit at the top of the Add screen.\n'
            'The location for Storage Items and Inventory Items consists of a General location and an optional Specific location. (More detail on locations is in Locations, below.)',
            excerpt: const AddFormMock(),
          ),
          AppDivider.horizontal,
          _section(
            4,
            'Additional details you can add for Storage Items and Inventory Items are not the same. You can add more details for the Inventory Items because the information is needed if you want to generate a Personal Inventory Report for insurance or other purposes. You can see the detail input portions of the Add screens above.',
            excerpt: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('STORAGE',
                    style: AppText.dialogSection.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                const StorageDetailMock(),
                const SizedBox(height: 12),
                Text('INVENTORY',
                    style: AppText.dialogSection.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                const InventoryDetailMock(),
              ],
            ),
            excerpt2: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PHOTO & NOTES',
                    style: AppText.dialogSection.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                const PhotoNotesMock(),
              ],
            ),
            body2: 'Also shown above are the photo and notes input options for all three location logs. There are three options to add a photo. You can take a photo with the device camera, select a photo from the device\u2019s photo gallery, or add from the clipboard. The clipboard button will only be active when you have copied a photo to the clipboard. A thumbnail of the photo you add will be displayed, but you can also tap the View Photo button to display it larger in a separate screen where it can be zoomed. The Remove button allows you to remove a photo if you wish to do that.\n'
                'You may also add notes for each item. This provides you a place to record any text you wish to describe or document the item. If you have a story or background information you wish to keep for the item you can do that here.\n'
                'The notes and photos can be hidden to save screen space. This might be especially desirable if you don\u2019t use these features. Hiding these items does not change their contents, it simply hides them from being viewed on this screen. The notes area when visible is only a small scrollable area on the screen, but it can be expanded to a larger area for ease of entering and reading larger amounts of text.\n'
                'Once you have entered all the information for an entry, tap the + Add Item button to save the item. Notice the Add screen does not close and the location information stays on the screen after each add. This process allows you to enter another item and the location is unchanged so you can easily add another item stored in the same location. However, if the next item you add is stored in another location make sure you change it. When you have no additional items to add use the back arrow at the top of the screen to return to the main page.',
          ),
          AppDivider.horizontal,
          _section(
            5,
            'Every Storage item and Inventory item has a General location (a room, an outbuilding, a storage rental) and may also have a Specific location (a shelf, a closet, a box, or a bin).\n'
            'WhereLog enforces some rules to make sure your location options cannot be ambiguous. There can be no repeats in the General location options. For example, you must have distinct names for multiple bedrooms. You can choose the names that you prefer to distinguish General locations. Specific locations belong to a General location and that means the Specific locations for a General location cannot be repeated. If you have two Bins in a General location they must be named differently (and also should be labeled accordingly). Of course, you can have the same Bin 1 in two different General locations.\n'
            'The Location options can be added as you enter a new Storage or Inventory item, or added in advance through the Location Options maintenance feature accessed through the menu on the main page. (Menu > Location Options)\n'
            'The Location Options is presented in a collapsible tree structure. Each General location lives on a card you can expand: the Specific location options hang off the descending branches.\n'
            'The tree structure can be viewed in an edit mode or a read-only mode, using the pencil switch at the top of the screen. The page opens in edit mode. When in edit mode, the last branch for a General location is an add row where you can type a new Specific and tap + Add. While in edit mode you can also tap an entry and a popup dialog will allow you to edit or delete the entry. The delete is only enabled if there are no items linked to that location. There is also a place at the bottom of the screen to add a new General.',
            excerpt: const LocationCardMock(),
          ),
          AppDivider.horizontal,
          _section(
            6,
            'The location for a Place of Interest (POI) is always GPS coordinates with optional address. Saving the GPS locations of Places of Interest that have no address is an important feature of WhereLog.\n'
            'There are three ways to import and add a place using the POI Import dialog. The dialog can be accessed by tapping the POI Import icon shown above. From the dialog you can add shared items from the queue, items copied to clipboard, and items from GPX files.\n'
            'Shared Items: WhereLog can receive shares from any app that shares locations. Drop a pin or search for a location in your device\u2019s mapping app and then share the location with WhereLog. Shared locations are automatically added to the import queue. A red badge next to the POI import dialog icon displays the number of pending locations in the queue. You may import locations from the queue by clicking the green check mark next to an import entry. You may discard a pending import by clicking on the X.\n'
            'Clipboard Items: Mapping apps and other apps will let you copy locations to the clipboard. The Paste from Clipboard button lets you add a location you have added to the clipboard.\n'
            'GPX files: There are two ways to process a GPX file. You can share a GPX file to WhereLog from your device\u2019s file manager, and the location(s) in it will be added to the POI import queue. You can also use the Import GPX File button to locate a GPX file and select it to be added to WhereLog.',
            excerpt: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PoiImportButtonMock(),
                SizedBox(height: 8),
                PoiImportDialogMock(),
              ],
            ),
            excerpt2: const PoiAddMock(),
            body2: 'Any location that you add from the POI import dialog will provide the opportunity to view a location pin on a map and adjust it to the exact position you want saved.\n'
                'There are also three ways to add the location for a Place of Interest from the Add screen.\n'
                'You may type the coordinates directly into the latitude and longitude fields on the Add screen.\n'
                'You may click the Device GPS button to capture the device\u2019s current location.\n'
                'You may click the Map GPS button and drop a pin to select a location on the Map. While viewing the map you may search for locations near to the location where you want to drop your pin. This feature uses a map displayed within the WhereLog app.\n'
                'You may add an optional address to any POI you create. If there is an address known for the location you are importing, it will usually appear automatically in the address field. There is also a read-only field that attempts to record the source through which a POI was added.',
          ),
          AppDivider.horizontal,
          _section(
            7,
            'Finding things or places when you need them is the most important benefit of the WhereLog app. To assist you finding the WhereLog entry you need, each tab has a search function that can be accessed by tapping the magnifying glass (search icon). Just type a portion of the name to narrow down the entries.\n'
            'There is also a filter/sort icon (the tune icon) on the tab topbar for the Storage and Inventory Items. You may apply a filter and a sort which may be helpful in locating or viewing entries. There are Distance and Map icons at the top of the Places of Interest tab. Both of these may be helpful when browsing entries or search for a particular place.',
            excerpt: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchMock(),
                PoiTopBarMock(),
              ],
            ),
          ),
          AppDivider.horizontal,
          _section(
            8,
            'The SELECT button at the bottom of the main page tabs shifts the list into a Select mode allowing you to select items in the list of the selected tab. You can select entries by tapping the checkbox shown next to each entry. A checkmark in the box identifies the selected entries. The bar at the bottom shows the number you have selected.\n'
            'While in Select mode buttons are shown below the list of items on the tab. MOVE does not apply to Places of Interest, so the Places tab shows only CANCEL and DELETE. The CANCEL button will end the Select mode and no action will be performed on the selected entries. The other buttons allow you to either delete the selected entries or move Storage or Inventory entries to a different location (change the location at which they are stored or located). MOVE and DELETE stay greyed out until you check at least one entry. If you select the MOVE option you will need to specify a new location just as you specify a new location when adding or editing items. This feature should be used carefully because there is no way to automatically reverse this move.',
            excerpt: const SelectBarMock(),
          ),
          AppDivider.horizontal,
          _section(
            9,
            'The Export/Import feature can be accessed from the main page menu (Menu > Export / Import). You can export your data anytime to a ZIP backup. It will save all your data including photos in a ZIP file. You must select a folder where the ZIP file will be saved each time you export (backup) your data. The name of the ZIP file identifies the precise time the export was performed.\n'
            'You may also restore data from any backup at any time you choose. An import (restore) automatically performs an internal backup (not accessible except through the Export/Import page). This backup is performed as a special safety measure to protect your data. You may also restore data from these internal backups. (Importing/restoring from an internal backup does not automatically create the internal backup).\n'
            'It is a good practice to create a backup on a regular basis and store it safely on another device or in the cloud.',
            subtitle: 'Export / Import',
            excerpt: const ExportImportMock(),
          ),
          AppDivider.horizontal,
          _section(
            10,
            'There is a Reports option on the main page menu. (Menu > Reports). The first feature on this page is the Personal Inventory Report, a print-ready PDF for insurance records \u2014 it opens as a preview you can print or share to Files.\n'
            'There is also an option to create three CSV files which can be viewed and manipulated as a spreadsheet. These three files are an export of the three types of data stored in your app. You can use these files for any purpose you wish, but you cannot load them back into WhereLog.',
            excerpt: const ReportsMock(),
          ),
          AppDivider.horizontal,
          _section(
            11,
            'There are a few settings that allow you to tailor WhereLog to your preferences available through main page menu (Menu > Settings).\n'
            'You may set the Display Mode for the app to one of three options; System, Light, or Dark\n'
            'You may change the order of the three tabs on the Main Screen. You can simply drag the tabs into the order you prefer them to be on the main page.\n'
            'The Confirm Deletes setting lets you determine if the app will ask you for a confirmation when deleting information from the app. Leaving this on is the safe option; turning it off and data will be immediately deleted when you tap a delete button or icon.\n'
            'The Intro setting permits the Intro screens to be shown at app startup after they have been turned off. The Intro screens are shown each time you start up the app until you choose to turn them off. Any time the screens play you are given an opportunity to turn them off. This feature is included so you can intentionally reverse that decision.',
          ),
          AppDivider.horizontal,
          _section(
            12,
            'If something goes wrong you can always send an email message to WhereLog support. (Menu > Contact / Support). The version number from your app is automatically included in the email.\n'
            'If a share into WhereLog misbehaves, long-press the WhereLog title on the main screen for a copyable diagnostics report to send with your message.',
          ),
          AppDivider.horizontal,
          // Onboarding replay (2026-11-15, build 24): the seven first-run
          // screens, for anyone who skipped through too fast. Opens as a
          // replay — the last button says Done, and nothing is re-recorded.
          TextButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => OnboardingScreen(
                  isFirstRun: false,
                  onDone: () => Navigator.of(context).pop(),
                ),
              ));
            },
            child: const Text('See the introduction again',
                style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 24),
          // Bottom space (2026-11-20, build 69): one viewport of
          // space after the last section, so SETTINGS and GETTING
          // HELP — and any section — can scroll to the top of the
          // view. Without it, the last sections' target is clamped
          // to maxScrollExtent and a Contents tap on them can do
          // nothing at all. The space sits after the final button,
          // past the end of the content, not between sections.
          SizedBox(height: MediaQuery.of(context).size.height),
          ],
        ),
      ),
    );
  }
}
