import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight launcher utilities for WhatsApp, phone, email and generic URLs.
/// Always returns a boolean to indicate whether the attempt to open succeeded.
class SocialLauncher {
  const SocialLauncher._();

  /// Open a WhatsApp conversation using wa.me deep link.
  /// Accepts E.164 numbers like +15551234567 or raw numbers; spaces and dashes are stripped.
  static Future<bool> openWhatsApp({required String phone, String? message}) async {
    try {
      final normalized = _normalizePhone(phone);
      if (normalized.isEmpty) return false;
      final params = <String, String>{
        if (message != null && message.trim().isNotEmpty) 'text': message.trim(),
      };
      final uri = Uri(
        scheme: 'https',
        host: 'wa.me',
        path: normalized,
        queryParameters: params.isEmpty ? null : params,
      );
      // Prefer external application on devices; default on web.
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      final ok = await launchUrl(uri, mode: mode);
      if (!ok) debugPrint('SocialLauncher.openWhatsApp failed for $uri');
      return ok;
    } catch (e) {
      debugPrint('SocialLauncher.openWhatsApp error: $e');
      return false;
    }
  }

  /// Start a phone call using tel: scheme.
  static Future<bool> dialPhone(String phone) async {
    try {
      final normalized = _normalizePhone(phone);
      if (normalized.isEmpty) return false;
      final uri = Uri(scheme: 'tel', path: normalized);
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      final ok = await launchUrl(uri, mode: mode);
      if (!ok) debugPrint('SocialLauncher.dialPhone failed for $uri');
      return ok;
    } catch (e) {
      debugPrint('SocialLauncher.dialPhone error: $e');
      return false;
    }
  }

  /// Compose an email using mailto: scheme.
  static Future<bool> composeEmail({required String to, String? subject, String? body}) async {
    try {
      final qp = <String, String>{
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      };
      final uri = Uri(scheme: 'mailto', path: to, queryParameters: qp.isEmpty ? null : qp);
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      final ok = await launchUrl(uri, mode: mode);
      if (!ok) debugPrint('SocialLauncher.composeEmail failed for $uri');
      return ok;
    } catch (e) {
      debugPrint('SocialLauncher.composeEmail error: $e');
      return false;
    }
  }

  /// Open a generic HTTPS link.
  static Future<bool> openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      final ok = await launchUrl(uri, mode: mode);
      if (!ok) debugPrint('SocialLauncher.openLink failed for $uri');
      return ok;
    } catch (e) {
      debugPrint('SocialLauncher.openLink error: $e');
      return false;
    }
  }

  static String _normalizePhone(String raw) {
    // Remove spaces, parentheses, dashes. Keep leading + if present.
    final trimmed = raw.trim();
    final keepPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return keepPlus ? '+$digitsOnly' : digitsOnly;
  }
}
