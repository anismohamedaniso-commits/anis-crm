import 'package:flutter/material.dart';

/// Shared snackbar utility to avoid code duplication across pages.
class AppSnackbar {
  AppSnackbar._();

  /// Show a success snackbar with a check icon.
  static void success(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  /// Show an error snackbar with an error icon.
  static void error(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  /// Show an info snackbar with a neutral icon.
  static void info(BuildContext context, String message) {
    _show(context, message, isError: false, icon: Icons.info_outline, color: Theme.of(context).colorScheme.primary);
  }

  static void _show(
    BuildContext context,
    String message, {
    bool isError = false,
    IconData? icon,
    Color? color,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.check_circle_outline),
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? (isError ? cs.error : const Color(0xFF2E7D32)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }
}
