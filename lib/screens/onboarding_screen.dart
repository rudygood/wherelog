import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// First-run introduction (build 31, 2026-11-16): seven screens, one idea
/// each, shown once on first launch. Format, per Rudy 2026-11-16
/// (corrected that day — builds 28-30 had misread it as white top over
/// a blue bottom): every slide is white — imagery on top, instructive
/// text below — with a blue band at the bottom holding only the dots
/// and the Next button. The splash's top blue was removed because on
/// Android it made the status-bar info (battery, time) hard to read;
/// the top stays white. The splash is NOT inverted: icon on top, text
/// below, as originally designed. Screen 2 is the tabs slide, its text
/// Rudy's own: the headline breaks after TELL YOU, with an em dash
/// after THREE TABS, then three sections, each a bold tab title with
/// regular text, over a rendering of the main page's top — app header
/// with the hamburger, and the tabs, in the app's own shades (scaffold
/// behind the header, scaffoldDark strip, surface selected tab). Shown
/// again from Help ("See the introduction again") — then the last
/// button says Done instead of Get started, and nothing is re-recorded.
/// No location permission is asked here: that comes in context, the
/// first time someone adds a place. Naming: the inventory tab is
/// "Personal Inventory" here, per Rudy's 2026-11-15 decision.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone, this.isFirstRun = true});

  /// First run: the caller records the seen flag and moves on to the
  /// home screen. Replay (from Help): the caller just closes this page.
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

  void _skip() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    final isLast = _page == 6;
    return Scaffold(
      // The blue band at the bottom, behind the dots and the button.
      backgroundColor: AppColors.logoBlue,
      body: SafeArea(
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
                      const _ContentPage(
                        visual: _LocationMock(),
                        title: 'Narrow it down, then pin it down',
                        body: 'A General narrows the search \u2014 a room, a building, a property. A Specific picks out one spot inside it. Add locations as you add items, or manage them all from the menu.',
                      ),
                      const _ContentPage(
                        visual: _DetailChips(),
                        title: 'Add what matters, skip the rest',
                        body: 'If you choose, each item can hold more than a name and a place. For insurance, the value, the photo, and the serial number are the ones that count.',
                      ),
                      const _ContentPage(
                        visual: _MapMock(),
                        title: 'Places with no address',
                        body: 'Record a place by its GPS coordinates \u2014 from your device, from a map, or from another source. Then see it on the map or get directions back to it. And if it has an address, you can store that too.',
                      ),
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
                // Dots + action button, on the blue band.
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(7, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
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
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.logoBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(isLast
                              ? (widget.isFirstRun ? 'Get started' : 'Done')
                              : 'Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Skip / Close, top right, over the white top.
            Positioned(
              top: 8,
              right: 16,
              child: TextButton(
                onPressed: _skip,
                style: TextButton.styleFrom(
                  foregroundColor: _kInkSoft,
                ),
                child: Text(
                  widget.isFirstRun ? 'Skip' : 'Close',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
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
                const SizedBox(height: 20),
                Image.asset(
                  'assets/icon/solutionwise_logo.png',
                  width: 170,
                  errorBuilder: (c, e, s) => const Text(
                    'SolutionWise',
                    style: TextStyle(
                      color: _kTaglineGrey,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
          flex: 3,
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
          flex: 8,
          child: Container(
            width: double.infinity,
            color: AppColors.white,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(32, 24, 32, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THREE TABS \u2014 TELL YOU\nWHERE YOUR THINGS ARE LOCATED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.25,
                      color: _kInk,
                    ),
                  ),
                  SizedBox(height: 16),
                  _TabsSection(
                    label: 'Storage Items',
                    body: 'Log where you have stored items so you can easily locate them even if they are in boxes and bins, on shelves, under tarps.',
                  ),
                  SizedBox(height: 14),
                  _TabsSection(
                    label: 'Personal Inventory',
                    body: 'Log where your assets are located. Record details you might need. Create a Personal Inventory report suitable for insurance purposes.',
                  ),
                  SizedBox(height: 14),
                  _TabsSection(
                    label: 'Places of Interest',
                    body: 'Log where places you want to find again are located using GPS coordinates. Places with or without addresses such as camp sites, trail heads, fishing holes or a favorite pizza stop.',
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
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.35,
            color: _kInkSoft,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

/// Screens 3-7: one idea each — a widget visual on top, a title and
/// one or two short sentences below, all on white.
class _ContentPage extends StatelessWidget {
  const _ContentPage({
    required this.visual,
    required this.title,
    required this.body,
    this.flexTop = 4,
    this.flexBottom = 6,
  });

  final Widget visual;
  final String title;
  final String body;
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
                padding: const EdgeInsets.symmetric(horizontal: 32),
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
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 12),
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
      padding: const EdgeInsets.only(top: 8),
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

/// General and Specific, with Rudy's own example: the Christmas lights
/// live in Red & Green Bin #1, in the Attic. The container names the
/// spot, so the Specific distinguishes.
class _LocationMock extends StatelessWidget {
  const _LocationMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kCard,
        border: Border.all(color: _kLine),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_outlined, size: 20, color: AppColors.logoBlue),
              const SizedBox(width: 8),
              Text(
                'General: Attic',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: _kAlert),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Specific: Red & Green Bin #1',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Christmas Lights',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kInkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
