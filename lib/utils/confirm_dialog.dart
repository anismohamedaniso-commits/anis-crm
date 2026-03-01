import 'package:flutter/material.dart';

/// Confirmation dialog utility for destructive actions.
class ConfirmDialog {
  ConfirmDialog._();

  /// Show a confirmation dialog before a destructive action.
  ///
  /// Returns `true` if the user confirmed, `false` otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
    IconData icon = Icons.warning_amber_rounded,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: (confirmColor ?? cs.error).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: confirmColor ?? cs.error, size: 28),
        ),
        title: Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        content: Text(
          message,
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: confirmColor ?? cs.error,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(confirmLabel),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
