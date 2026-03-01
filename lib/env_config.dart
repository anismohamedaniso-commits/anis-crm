/// Centralized environment configuration.
///
/// All secrets and URLs are read from compile-time `--dart-define` flags
/// so nothing sensitive is hardcoded in source control.
///
/// Build example:
/// ```bash
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://your-project.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your-anon-key \
///   --dart-define=API_BASE_URL=https://your-api.example.com
/// ```
///
/// For local development the defaults point to localhost so you can
/// run `flutter run` without any flags.
class EnvConfig {
  EnvConfig._();

  // ── Supabase ──────────────────────────────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://chqejdsgevbvsaqiejps.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '', // must be supplied via --dart-define in production
  );

  // ── Backend API server ────────────────────────────────────────────────
  /// Base URL of the FastAPI server (no trailing slash).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  // ── Helpers ───────────────────────────────────────────────────────────
  /// `true` when the app was built with production dart-defines.
  static bool get isProduction =>
      supabaseAnonKey.isNotEmpty &&
      !apiBaseUrl.contains('127.0.0.1') &&
      !apiBaseUrl.contains('localhost');
}
