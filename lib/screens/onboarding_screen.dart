import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// First-run introduction (build 25, 2026-11-15): seven screens, one idea
/// each, shown once on first launch. Screen 1 is Rudy's splash design
/// (blue field, app icon, "Where is your stuff?", wordmark, SolutionWise
/// signature). Screens 2-7 are the reworked tour, built from Rudy's two
/// draft screens of 2026-11-15 plus the finding screen he asked for:
/// the three tabs, General and Specific locations, the details an item
/// can hold, places with no address (GPS), finding things again, and
/// your data staying yours. The tour teaches the app's model — the
/// things the store page doesn't — one idea per screen, each with a
/// widget visual (tab bar, location rows, detail chips, mini map,
/// search bar) rather than a paragraph. Shown again from Help ("See the
/// introduction again") — then the last button says Done instead of Get
/// started, and nothing is re-recorded. No location permission is asked
/// here: that comes in context, the first time someone adds a place.
/// Naming: the inventory tab is "Personal Inventory" here, per Rudy's
/// 2026-11-15 decision — the rename exception for onboarding references
/// (the rest of the app takes the new name with the Help round).
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

  // Dots sit on the splash page's blue on page 0, on the scaffold
  // everywhere else — the active dot follows the page's accent.
  Color get _activeDot {
    switch (_page) {
      case 0:
        return AppColors.white;
      case 1:
        return AppColors.logoBlue;
      case 2:
        return AppColors.alert;
      case 3:
        return AppColors.buttonBg;
      case 4:
        return AppColors.notice;
      case 5:
        return AppColors.logoBlue;
      default:
        return AppColors.buttonBg;
    }
  }

  Color get _inactiveDot =>
      _page == 0 ? AppColors.whiteDim : AppColors.border;

  @override
  Widget build(BuildContext context) {
    final isLast = _page == 6;
    final onSplash = _page == 0;
    return Scaffold(
      backgroundColor: onSplash ? AppColors.logoBlue : AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // Skip / Close, top right. White on the splash page's blue,
            // secondary text everywhere else.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  widget.isFirstRun ? 'Skip' : 'Close',
                  style: TextStyle(
                    color: onSplash ? AppColors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _SplashPage(),
                  _ContentPage(
                    visual: _TabBarMock(),
                    title: 'Three tabs to track your stuff',
                    body: 'Storage Items and Personal Inventory hold what you own. Places of Interest holds the places.',
                  ),
                  _ContentPage(
                    visual: _LocationMock(),
                    title: 'A place for everything',
                    body: 'Every item has a General area \u2014 a room, a building, a property \u2014 and an optional Specific spot, like a shelf, a closet, or a bin. Add locations as you add items, or manage them all from the menu.',
                  ),
                  _ContentPage(
                    visual: _DetailChips(),
                    title: 'Track the details that matter',
                    body: 'If you choose, each item can hold more than a name and a place:',
                  ),
                  _ContentPage(
                    visual: _MapMock(),
                    title: 'Places with no address',
                    body: 'Record a place by its GPS coordinates \u2014 from your device, from a map, or from another source. Then see it on the map or get directions back to it. And if it has an address, you can store that too.',
                  ),
                  _ContentPage(
                    visual: _SearchMock(),
                    title: 'Finding it again is the payoff',
                    body: 'Tap the magnifier to search by name, or the filter button to show only one place \u2014 a room, a building, a shelf. The list narrows as you type.',
                  ),
                  _ContentPage(
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
            // Dots + action button.
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
                          color: active ? _activeDot : _inactiveDot,
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
      ),
    );
  }
}

/// Screen 1: Rudy's splash as designed (2026-11-11) — blue field with the
/// app icon, then the tagline, the wordmark in the brand split, and the
/// SolutionWise signature. Deliberately mode-independent: it is his
/// design as drawn, light in both modes.
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
            color: AppColors.logoBlue,
            child: Center(
              child: Container(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66FFFFFF),
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 170,
                  height: 170,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.inventory_2,
                    size: 120,
                    color: AppColors.white,
                  ),
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
                  'Where is your stuff?\nKeep track of it with',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 34),
                    children: [
                      const TextSpan(
                        text: 'Where',
                        style: TextStyle(color: AppColors.logoBlue),
                      ),
                      TextSpan(
                        text: 'Log',
                        // AppColors.alert is a getter (brightness-aware),
                        // not a const, so this span cannot be const.
                        style: TextStyle(color: AppColors.alert),
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
                      color: Color(0xFF6B6B6B),
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

/// Screens 2-7: one idea each — a widget visual, a title, and one or
/// two short sentences. Nothing more; the idea is the page.
class _ContentPage extends StatelessWidget {
  const _ContentPage({
    required this.visual,
    required this.title,
    required this.body,
  });

  final Widget visual;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          visual,
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 15,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three tabs as the user will see them — Storage Items active.
/// Screen 2's visual: the names themselves are the orientation.
class _TabBarMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(6),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.logoBlue.withOpacity(0.12) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
            height: 1.25,
            color: active ? AppColors.logoBlue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// General and Specific as a two-row hierarchy. Screen 3's visual.
class _LocationMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_outlined,
                  size: 20, color: AppColors.logoBlue),
              const SizedBox(width: 8),
              Text(
                'General: House',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 20, color: AppColors.alert),
                const SizedBox(width: 8),
                Text(
                  'Specific: Kitchen \u00b7 top shelf',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
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
/// Screen 4's visual.
class _DetailChips extends StatelessWidget {
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
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            d,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A stylised map: river, roads, a pin, its label. Screen 5's visual —
/// the Fishing Spot from Rudy's draft, drawn with widgets.
/// (Maps stay light in dark mode too, like the real map.)
class _MapMock extends StatelessWidget {
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
            // The pin and its label.
            const Align(
              alignment: Alignment(0.15, 0.1),
              child: Icon(
                Icons.location_on,
                size: 40,
                color: Color(0xFFC62828),
              ),
            ),
            Align(
              alignment: const Alignment(0.15, -0.45),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF9E9E9E)),
                ),
                child: const Text(
                  'Fishing Spot',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
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

/// The search field and filter button as they appear on the item lists.
/// Screen 6's visual: the payoff, shown the way the user will meet it.
class _SearchMock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Search items\u2026',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.tune, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// An icon in the page's accent colour, for pages whose visual is
/// simply an idea. Screen 7's visual.
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
