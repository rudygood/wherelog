import 'package:flutter/material.dart';

import '../settings_service.dart';
import '../theme/app_theme.dart';

/// First-run introduction (build 37, 2026-11-16): seven screens, one idea
/// each. Format, per Rudy 2026-11-16 (corrected that day — builds 28-30
/// had misread it as white top over a blue bottom): every slide is
/// white — imagery on top, instructive text below — with a blue band
/// at the bottom holding the controls. The splash's top blue was
/// removed because on Android it made the status-bar info (battery,
/// time) hard to read; the top stays white. The splash is NOT
/// inverted: icon on top, text below, as originally designed. The
/// band is short (build 37: 2px top padding, no bottom padding, no
/// gap between the rows, 28px Next/Back, 20px Skip/Turn-off — a
/// further ~20px off build 36, to give the pages room on a phone).
/// Headlines (build 37) all use Roboto Condensed Bold (bundled as an
/// asset, the condensed cut of the same Roboto the app uses) at one
/// size, 16px, with a tight 0.8 line height so the two lines sit
/// ~6px closer — page 2's "WHERE YOUR THINGS ARE LOCATED" now fits
/// on one line, so LOCATED is on line 2. The text sits just under
/// the visual rather than floating centered: pages 3-7 use a 3/7
/// flex split, and the content pages carry no top padding. The tabs
/// slide (build 38) uses a 5/15 split — its visual (header 56px +
/// tabs 48px = 104px) sits in a ~180px area, so the headline sits
/// ~17px higher than build 37's 3/8 split and the ~46px of white
/// space that sat below the tab bar is mostly reclaimed. Screen 3's
/// form (build 38) has 6px after the General field and 8px after
/// the Specific field — 6px cut after each of the two location
/// fields, 12px gained in all.
/// Screen 2 is the tabs slide, its text Rudy's own: the headline breaks after
/// TELL YOU, with an em dash after THREE TABS, then three sections,
/// each a bold tab title with regular text, over a rendering of the
/// main page's top — app header with the hamburger, and the tabs, in
/// the app's own shades (scaffold behind the header, scaffoldDark
/// strip, surface selected tab). Screen 3 is the real Add Storage
/// screen (build 35): the Add Storage form rebuilt as widgets that
/// mimic the real add page's fields, with Rudy's values — Garage /
/// Hardware Bin / Replacement Door Hinges — and his own text on
/// location and naming. The concatenated summary line is not
/// reproduced, and the Note now opens screen 4, where the details
/// live. Shown again from Help ("See the introduction again") — then
/// the last button says Done instead of Get started, and nothing is
/// re-recorded.
/// No location permission is asked here: that comes in context, the
/// first time someone adds a place. Naming: the inventory tab is
/// "Personal Inventory" here, per Rudy's 2026-11-15 decision.
///
/// Intro on/off (build 33): the tour shows on launch while the Intro
/// setting is on, and stays on until the user turns it off — from the
/// tour's own "Turn off intro" button or the Intro toggle in
/// Settings. Finishing (Get started) or skipping does NOT turn it
/// off, so the tour stays available for another review. The band
/// holds two rows: Back | dots | Next, then "Skip intro" and
/// "Turn off intro" side by side (first run only); in replay the
/// second row is a single Close button. Back is greyed out on the
/// first page; swiping still works. Pages 2-7 use the app's usual
/// 6px side margins on phones, squeezed vertically.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.isFirstRun = true});

  /// First run: the caller just moves on to the home screen. The
  /// Intro setting is untouched by finishing or skipping — only
  /// "Turn off intro" (or the Settings toggle) switches it off.
  /// Replay (from Help): the caller just closes this page.
  final VoidCallback onDone;

  /// True on first launch; false when re-shown from Help.
  final bool isFirstRun;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// The tour is light in both modes (like the splash was): fixed light
// values, never the brightness-aware AppColors getters. (logoBlue,
// white, whiteDim and buttonBg are mode-independent already, so they
// are used as-is.)
const _kInk = Color(0xFF1A1A1A);
const _kInkSoft = Color(0xFF444444);
const _kCard = Color(0xFFFAF6F0);
const _kLine = Color(0x61000000);
const _kStrip = Color(0xFFEDE8DF);
const _kScaffold = Color(0xFFF5F3EE);
const _kAlert = Color(0xFFC62828);
const _kTaglineGrey = Color(0xFF6B6B6B);

/// The tour's side margins: the app's usual 6px on phones, roomier
/// 32px on wider screens so the text does not run edge to edge.
double _contentHPad(BuildContext context) =>
    MediaQuery.of(context).size.width < 600 ? 6.0 : 32.0;

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 6) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDone();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Skip this showing only: the tour comes back next launch, because
  /// the Intro setting is untouched.
  void _skip() => widget.onDone();

  /// Compact white text button for the band's second row.
  Widget _bandTextButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }

  /// Turn the tour off for good (until re-enabled in Settings), then
  /// close it.
  Future<void> _turnOff() async {
    try {
      await SettingsService().setShowIntro(false);
    } catch (_) {}
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == 6;
    // Bottom clearance below the band (the home-indicator room),
    // 10px less than the system inset: the room below the
    // Skip-intro row absorbs the 10px gap between the rows, so the
    // band adds no height and the pages keep their room.
    final bottomPad = MediaQuery.of(context).padding.bottom - 10;
    final bottomPadding = bottomPad < 0 ? 0.0 : bottomPad;
    return Scaffold(
      // The blue band at the bottom, behind the dots and the button.
      backgroundColor: AppColors.logoBlue,
      body: SafeArea(
        // No bottom inset here: the band carries its own bottom
        // clearance (above), 10px less than the system inset.
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      const _SplashPage(),
                      const _TabsPage(),
                      const _AddStoragePage(),
                      const _ContentPage(
                        visual: _DetailChips(),
                        visualTopPad: 24,
                        title: 'ADD USEFUL ITEM DETAILS\nCREATE AN INVENTORY REPORT',
                        body: 'The optional details can be useful especially those that allow you to generate a Personal Inventory Report for insurance purpose. See the menu.',
                        title2: 'MAINTAIN YOUR LOCATION OPTIONS',
                        body2: 'A hierarchical editing tool is useful for creating and maintaining Location Options. See the menu.',
                      ),
                      const _PoiPage(),
                      const _ContentPage(
                        visual: _SearchMock(),
                        title: 'Finding it again is the payoff',
                        body: 'Tap the magnifier to search by name \u2014 the list narrows as you type. Tap the filter button to show only one place: a room, a building, a shelf.',
                      ),
                      const _ContentPage(
                        visual: _IconDisc(
                          icon: Icons.shield_outlined,
                          accent: AppColors.buttonBg,
                        ),
                        title: 'Your data stays yours',
                        body: 'Everything lives on your device. No account, no subscription. Export or back it up any time \u2014 your data is never locked inside the app.',
                      ),
                    ],
                  ),
                ),
                // Two rows on the blue band: Back | dots | Next, then
                // the two ways to end the intro side by side (first
                // run) or a single Close (replay). Next is a plain
                // text button like Back (build 39) — the white
                // ElevatedButton crowded the right edge — and a
                // 10px gap sits between the rows (build 39). The
                // gap adds no height (build 40): the band's bottom
                // clearance is 10px less than the system inset, so
                // the room below the Skip-intro row absorbs it.
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 2, 16, bottomPadding),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TextButton(
                            onPressed: _page > 0 ? _back : null,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.white,
                              disabledForegroundColor: AppColors.whiteDim,
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Back'),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(7, (i) {
                                final active = i == _page;
                                return AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  width: active ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.white
                                        : AppColors.whiteDim,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                          ),
                          TextButton(
                            onPressed: _next,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.white,
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(isLast
                                ? (widget.isFirstRun ? 'Get started' : 'Done')
                                : 'Next'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: widget.isFirstRun
                            ? [
                                _bandTextButton('Skip intro', _skip),
                                const SizedBox(width: 24),
                                _bandTextButton('Turn off intro', _turnOff),
                              ]
                            : [
                                _bandTextButton('Close', _skip),
                              ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 1: Rudy's splash as designed (2026-11-11) — icon on top, the
/// tagline, the wordmark in the brand split, and the SolutionWise
/// signature below — all on white; the blue at the top is gone (it made
/// the Android status-bar info hard to read). The blue lives only in
/// the band at the bottom, with the dots and the button.
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Center(
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 170,
                height: 170,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.inventory_2,
                  size: 120,
                  color: _kInkSoft,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Where are your things?\nKeep track of them with',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kTaglineGrey,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 34),
                          children: [
                            TextSpan(
                              text: 'Where',
                              style: TextStyle(color: AppColors.logoBlue),
                            ),
                            TextSpan(
                              text: 'Log',
                              style: TextStyle(color: _kAlert),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // The SolutionWise Mobile Apps lockup, at the bottom
                // of the white portion, clear of the main message.
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Image.asset(
                    'assets/icon/solutionwise_icon_mobile_apps.PNG',
                    width: 260,
                    errorBuilder: (c, e, s) => const Text(
                      'SolutionWise',
                      style: TextStyle(
                        color: _kTaglineGrey,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Screen 2: the three tabs, in Rudy's own words (2026-11-16). Top: the
/// main page's top, reconstructed — app header with the hamburger, and
/// the tabs — in the app's own shades. Below: the headline (break after
/// TELL YOU, em dash after THREE TABS), then three sections, each a
/// bold tab title with regular text.
class _TabsPage extends StatelessWidget {
  const _TabsPage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            color: _kScaffold,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MainHeaderMock(),
                _TabBarMock(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 15,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  _contentHPad(context), 0, _contentHPad(context), 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Centered on the page: this column is left-aligned
                  // for the sections, so the heading needs its own
                  // centering, or it hugs the left edge.
                  const Center(
                    child: Text(
                      'THREE TABS \u2014 TELL YOU\nWHERE YOUR THINGS ARE LOCATED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.0,
                        color: _kInk,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  _TabsSection(
                    label: 'Storage Items',
                    body: 'Log where you stored items so you can easily locate them even if they are in boxes and bins, on shelves, or under tarps.',
                  ),
                  SizedBox(height: 8),
                  _TabsSection(
                    label: 'Personal Inventory',
                    body: 'Log where your assets are located. Add details for an insurance inventory report.',
                  ),
                  SizedBox(height: 8),
                  _TabsSection(
                    label: 'Places of Interest',
                    body: 'Log where places of interest are located with GPS coordinates. You will be able to easily return to camp sites, fishing holes, trail heads, and pizza stops without an address.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One section of the tabs slide: a bold tab title, then regular text.
class _TabsSection extends StatelessWidget {
  const _TabsSection({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: _kInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          body,
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.2,
            color: _kInkSoft,
          ),
        ),
      ],
    );
  }
}

/// Screen 3 (build 35, 2026-11-16): the Add Storage form, rebuilt as
/// widgets that mimic the real add page — the three fields as they
/// really are, with Rudy's values (Garage / Hardware Bin /
/// Replacement Door Hinges). The real form's summary line — the
/// concatenated "Replacement Door Hinges @ Garage / Hardware Bin" —
/// is NOT reproduced here; the fields carry the example, and leaving
/// it out gains the room the page needed. The Note moved to screen 4,
/// where the details live. (Build 34 showed the real screenshot
/// instead; a widget rebuild fits the page and keeps the field text
/// at a readable size.)
class _AddStoragePage extends StatelessWidget {
  const _AddStoragePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Center(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: _contentHPad(context)),
                child: const _AddFormMock(),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: _contentHPad(context)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    // Room above the heading so the text sits just
                    // below the form's name field instead of
                    // crowding (or overlapping) it.
                    SizedBox(height: 32),
                    // Centered on the page: this column is left-aligned
                    // for the blocks, so the heading needs its own
                    // centering, or it hugs the left edge.
                    Center(
                      child: Text(
                        'LOG STORAGE & INVENTORY\nWITH LOCATION & NAME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'RobotoCondensed',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.0,
                          color: _kInk,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Adding a new Storage or Inventory Item begins with the location; Every item must have a General Area and you can also add a Specific area. See the example above.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.35,
                        color: _kInkSoft,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Name the item you are logging carefully so it is not easily confused with other items when you search for it later.',
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.35,
                        color: _kInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Add Storage form's three fields, rebuilt as widgets that mimic
/// the real add page — same labels, same field height, same buttons.
/// A display copy only: the fields show Rudy's values and the buttons
/// do nothing. The real form's summary line (the concatenated
/// "item @ location") is deliberately not reproduced. Light-locked
/// like the rest of the tour: fixed light consts throughout, never
/// the brightness-aware AppColors/AppText getters, so the fields stay
/// white-on-white-readable in dark mode too.
class _AddFormMock extends StatelessWidget {
  const _AddFormMock();

  /// One field row: the label above, then the field box with its value
  /// and, for the location fields, the picker's dropdown and action
  /// buttons as they really are.
  Widget _field(String label, String value, bool hasButtons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: _kInkSoft,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                height: AppSize.fieldHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: _kLine),
                  borderRadius:
                      BorderRadius.circular(AppBorder.radius),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _kInk,
                  ),
                ),
              ),
            ),
            if (hasButtons) ...[
              const SizedBox(width: 6),
              Container(
                width: 36,
                height: AppSize.fieldHeight,
                decoration: BoxDecoration(
                  color: AppColors.buttonBg,
                  borderRadius:
                      BorderRadius.circular(AppRadius.button),
                ),
                child: const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 36,
                height: AppSize.fieldHeight,
                decoration: BoxDecoration(
                  color: AppColors.buttonBg,
                  borderRadius:
                      BorderRadius.circular(AppRadius.button),
                ),
                child: const Icon(
                  Icons.check,
                  size: 18,
                  color: AppColors.white,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('General Area (required)', 'Garage', true),
        const SizedBox(height: 6),
        _field('Storage Specific Area (optional)', 'Hardware Bin', true),
        const SizedBox(height: 8),
        _field('Storage Item (required)', 'Replacement Door Hinges', false),
      ],
    );
  }
}


/// The main page's header as it really is: the app icon, the wordmark,
/// and the hamburger menu at the right. (The import badge button only
/// appears while an import is pending, so it is not shown here.)
class _MainHeaderMock extends StatelessWidget {
  const _MainHeaderMock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Image.asset(
            'assets/icon/app_icon.png',
            width: 48,
            height: 48,
            errorBuilder: (c, e, s) => const Icon(Icons.inventory_2),
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5),
              children: [
                TextSpan(
                  text: 'Where',
                  style: TextStyle(color: AppColors.logoBlue),
                ),
                TextSpan(
                  text: 'Log',
                  style: TextStyle(color: _kAlert),
                ),
              ],
            ),
          ),
          const Spacer(),
          const Icon(Icons.menu, color: _kInk),
        ],
      ),
    );
  }
}

/// Screens 4-7: one idea each — a widget visual on top, a title and
/// one or two short sentences below, all on white. A page may carry a
/// second headline and paragraph (title2/body2, page 4 does), and its
/// visual may be given extra room from the top (visualTopPad).
class _ContentPage extends StatelessWidget {
  const _ContentPage({
    required this.visual,
    required this.title,
    required this.body,
    this.title2,
    this.body2,
    this.visualTopPad = 0,
    this.flexTop = 3,
    this.flexBottom = 7,
  });

  final Widget visual;
  final String title;
  final String body;
  final String? title2;
  final String? body2;
  final double visualTopPad;
  final int flexTop;
  final int flexBottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: flexTop,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    _contentHPad(context), visualTopPad, _contentHPad(context), 0),
                child: visual,
              ),
            ),
          ),
        ),
        Expanded(
          flex: flexBottom,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(_contentHPad(context), 0, _contentHPad(context), 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'RobotoCondensed',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.0,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      height: 1.4,
                      color: _kInkSoft,
                    ),
                  ),
                  if (title2 != null && body2 != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      title2!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'RobotoCondensed',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.0,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body2!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        height: 1.4,
                        color: _kInkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The real tab bar, as built in main.dart: a scaffoldDark strip, the
/// selected tab a surface "folder tab" with a strong three-side border
/// and rounded top corners, two-line labels.
class _TabBarMock extends StatelessWidget {
  const _TabBarMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kStrip,
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _tabCell('Storage\nItems', true),
          _tabCell('Personal\nInventory', false),
          _tabCell('Places of\nInterest', false),
        ],
      ),
    );
  }

  Widget _tabCell(String label, bool active) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: active
            ? BoxDecoration(
                color: AppColors.white,
                border: const Border(
                  top: BorderSide(color: _kLine),
                  left: BorderSide(color: _kLine),
                  right: BorderSide(color: _kLine),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              )
            : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
            height: 1.0,
            color: active ? _kInk : _kInkSoft,
          ),
        ),
      ),
    );
  }
}

/// The details an item can hold, as chips — scannable, not a sentence.
/// The fields are the real ones from the item record: photo, notes,
/// quantity, value (replacement), brand, model, serial number, price
/// (what was paid), acquisition date.
class _DetailChips extends StatelessWidget {
  const _DetailChips();

  @override
  Widget build(BuildContext context) {
    const details = [
      'Photo',
      'Notes',
      'Quantity',
      'Value',
      'Brand',
      'Model',
      'Serial number',
      'Price',
      'Acquisition date',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: details.map((d) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          decoration: BoxDecoration(
            color: _kCard,
            border: Border.all(color: _kLine),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            d,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kInk,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// The POI map screen as it really looks: the control strip at the top
/// right — zoom in, zoom out, recenter, satellite toggle — and a pin
/// with its label chip, the Fishing Spot from Rudy's draft.
/// (Maps stay light in dark mode too, like the real map.)
/// The top of the POI Add screen, rebuilt as widgets that mimic the
/// real form — the GPS LOCATION section (Latitude/Longitude fields and
/// the Device GPS / Map GPS buttons) and the PLACE NAME field, all
/// inside the section's bordered card. A display copy only: the fields
/// show the real labels and hint, the buttons do nothing. The real
/// Longitude label reads "Longitude" but truncates to "Longitu..." on
/// the phone (as in Rudy's reference), so the mock shows it that way.
/// Light-locked like the rest of the tour: fixed light consts
/// throughout, never the brightness-aware AppColors/AppText getters.
class _PoiAddMock extends StatelessWidget {
  const _PoiAddMock();

  /// A section label, as the real form's dialogSection style.
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 11,
        color: _kInkSoft,
        letterSpacing: 0.6,
      ),
    );
  }

  /// One field box, as the real form's fields: white, bordered,
  /// rounded, with its label (or hint) text inside.
  Widget _fieldBox(String text, {bool isHint = false}) {
    return Container(
      height: AppSize.fieldHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: _kLine),
        borderRadius: BorderRadius.circular(AppBorder.radius),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isHint ? FontWeight.w400 : FontWeight.w700,
          fontSize: isHint ? 12 : 16,
          color: isHint ? _kTaglineGrey : _kInk,
        ),
      ),
    );
  }

  /// One of the grey GPS buttons, as the real form's: 50px tall,
  /// buttonBg grey, white condensed-bold label.
  Widget _gpsButton(String label) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.buttonBg,
        borderRadius: BorderRadius.circular(AppBorder.radius),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'RobotoCondensed',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GPS LOCATION (required)'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: _kLine),
            borderRadius: BorderRadius.circular(AppBorder.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _fieldBox('Latitude')),
                  const SizedBox(width: 8),
                  Expanded(child: _fieldBox('Longitu...')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _gpsButton('Device GPS')),
                  const SizedBox(width: 8),
                  Expanded(child: _gpsButton('Map GPS')),
                ],
              ),
              const SizedBox(height: 12),
              _sectionLabel('PLACE NAME (required)'),
              const SizedBox(height: 6),
              _fieldBox('e.g. Great campsite', isHint: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page 5: the POI Add form mock on top, then the POI story below —
/// a headline, an "Add a POI" block, and an "Add GPS Coordinates"
/// block listing the ways to get coordinates, with the POI Import
/// icon beside the import options. A dedicated page (not _ContentPage)
/// because the second block is a nested list, not a paragraph.
class _PoiPage extends StatelessWidget {
  const _PoiPage();

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ',
              style: TextStyle(
                  fontSize: 14, height: 1.35, color: _kInkSoft)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.35,
                    color: _kInkSoft)),
          ),
        ],
      ),
    );
  }

  Widget _subItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('–  ',
              style: TextStyle(
                  fontSize: 14, height: 1.35, color: _kInkSoft)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.35,
                    color: _kInkSoft)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Center(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: _contentHPad(context)),
                child: const _PoiAddMock(),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: _contentHPad(context)),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'LOG PLACES OF INTEREST (POI)\nRETURN TO THEM ANYTIME',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'RobotoCondensed',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.0,
                          color: _kInk,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Log a Place of Interest with coordinates and a name. Add an address if needed.',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.35,
                        color: _kInkSoft,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Add GPS Coordinates',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        height: 1.35,
                        color: _kInkSoft,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _bulletItem('type the coordinates'),
                    _bulletItem('the device GPS coordinates'),
                    _bulletItem('drop a pin on a map'),
                    _bulletItem('import coordinates'),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ImageIcon(
                            const AssetImage(
                                'assets/icon/poi_import_icon.png'),
                            size: 29,
                            color: _kInk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _subItem('share from device map'),
                                _subItem('share a GPX'),
                                _subItem('use clipboard coordinates'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapMock extends StatelessWidget {
  const _MapMock();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        color: const Color(0xFFE9EFE7),
        child: Stack(
          children: [
            // River, running diagonally.
            Positioned(
              left: -80,
              top: 60,
              child: Transform.rotate(
                angle: 0.5,
                child: Container(
                  width: 420,
                  height: 34,
                  color: const Color(0xFFBFD9E8),
                ),
              ),
            ),
            // Roads.
            Positioned(
              left: -60,
              top: 28,
              child: Transform.rotate(
                angle: -0.25,
                child: Container(
                  width: 400,
                  height: 10,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              left: -40,
              top: 132,
              child: Transform.rotate(
                angle: 0.15,
                child: Container(
                  width: 400,
                  height: 10,
                  color: Colors.white,
                ),
              ),
            ),
            // The pin and its label, as the real markers draw them:
            // a surface chip with a border above an alert-red pin.
            const Align(
              alignment: Alignment(0.15, 0.15),
              child: Icon(
                Icons.location_on,
                size: 28,
                color: Color(0xFFC62828),
              ),
            ),
            Align(
              alignment: const Alignment(0.15, -0.4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0x61000000)),
                ),
                child: const Text(
                  'Fishing Spot',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            // The real control strip: zoom in, zoom out, recenter,
            // satellite toggle, top right.
            Positioned(
              right: 12,
              top: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _mapBtn(const Icon(Icons.add), 40, false),
                  const SizedBox(width: 8),
                  _mapBtn(const Icon(Icons.remove), 40, false),
                  const SizedBox(width: 12),
                  _mapBtn(const Icon(Icons.my_location), 56, true),
                  const SizedBox(width: 8),
                  _mapBtn(const Icon(Icons.satellite_alt), 40, false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapBtn(Widget icon, double size, bool primary) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary ? AppColors.buttonBg : AppColors.white,
        border: primary ? null : Border.all(color: _kLine),
      ),
      child: IconTheme(
        data: IconThemeData(
          color: primary ? AppColors.white : _kInk,
          size: primary ? 24 : 20,
        ),
        child: Center(child: icon),
      ),
    );
  }
}

/// The search/filter bar as it really appears on the item lists: the
/// count, then the tune square and the search square, both in the
/// scaffoldDark style with a light border.
class _SearchMock extends StatelessWidget {
  const _SearchMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '12 storage items',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: _kInkSoft,
            ),
          ),
          const Spacer(),
          _squareBtn(const Icon(Icons.tune, size: 29)),
          const SizedBox(width: 6),
          _squareBtn(const Icon(Icons.search)),
        ],
      ),
    );
  }

  Widget _squareBtn(Widget icon) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _kStrip,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kLine),
      ),
      child: IconTheme(
        data: IconThemeData(color: _kInk),
        child: Center(child: icon),
      ),
    );
  }
}

/// An icon in the page's accent colour, for pages whose visual is
/// simply an idea.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: accent),
    );
  }
}
