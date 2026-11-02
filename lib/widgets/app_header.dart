import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable App Header — now themed
/// [left arrow] + WhereLog (blue/red) + " - {screenName}" in theme textPrimary
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String screenName;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.screenName,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.scaffold,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 40,
      titleSpacing: 4,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: onBack ?? () => Navigator.pop(context),
      ),
      title: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          children: [
            const TextSpan(text: 'Where', style: AppText.logoWhere),
            const TextSpan(text: 'Log', style: AppText.logoLogAlert),
            TextSpan(
              text: ' - $screenName',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
