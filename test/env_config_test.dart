import 'package:flutter_test/flutter_test.dart';
import 'package:anis_crm/env_config.dart';

void main() {
  group('EnvConfig', () {
    test('supabaseUrl has a non-empty default', () {
      expect(EnvConfig.supabaseUrl, isNotEmpty);
      expect(EnvConfig.supabaseUrl, startsWith('https://'));
    });

    test('apiBaseUrl has a non-empty default', () {
      expect(EnvConfig.apiBaseUrl, isNotEmpty);
      expect(EnvConfig.apiBaseUrl, contains('127.0.0.1'));
    });

    test('isProduction is false with default values', () {
      // Default supabaseAnonKey is empty → isProduction should be false.
      expect(EnvConfig.isProduction, isFalse);
    });

    test('supabaseAnonKey defaults to empty (no secret in source)', () {
      // This proves the key is NOT hardcoded.
      expect(EnvConfig.supabaseAnonKey, isEmpty);
    });
  });
}
