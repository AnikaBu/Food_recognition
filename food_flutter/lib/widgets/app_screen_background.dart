import 'package:flutter/material.dart';
import '../theme/theme_palette.dart';

/// Reusable background widget that renders a full-screen vertical gradient
/// in dark mode matching the active theme palette
/// and transparent/child in light mode.
class AppScreenBackground extends StatelessWidget {
  final Widget child;

  const AppScreenBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;

    final tokens = AppThemeTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: tokens.backgroundGradient,
      ),
      child: child,
    );
  }
}
