import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact brand mark that automatically switches between black/white logo
/// based on the active theme/background. Optionally shows the brand caption.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.showText = true});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark ? AppBrand.logoWhiteAsset : AppBrand.logoBlackAsset;

    final logo = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.rocket_launch_outlined, size: size, color: Theme.of(context).colorScheme.onSurface),
    );

    final caption = Text(
      AppBrand.name,
      style: GoogleFonts.plusJakartaSans(
        fontSize: size * 0.32,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
      ),
    );

    return Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: logo, switchInCurve: Curves.easeOut, switchOutCurve: Curves.easeIn),
      if (showText) ...[
        const SizedBox(width: 10),
        caption,
      ]
    ]);
  }
}

/// Wider header widget for page headers (e.g., Dashboard)
class BrandHeaderBar extends StatelessWidget {
  const BrandHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: const BrandMark(size: 40, showText: true),
    );
  }
}
