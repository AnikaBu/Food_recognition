import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable background widget that renders a full-screen vertical gradient
/// in dark mode (lighter steel-navy at top to deep midnight-navy at bottom)
/// and transparent/child in light mode.
class AppScreenBackground extends StatelessWidget {
  final Widget child;

  const AppScreenBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.darkBackgroundGradient,
      ),
      child: child,
    );
  }
}
