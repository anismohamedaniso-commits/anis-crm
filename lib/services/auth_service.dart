import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:anis_crm/supabase/supabase_config.dart';
import 'package:anis_crm/env_config.dart';

/// User roles matching server-side constants
class UserRole {
  static const String accountExecutive = 'account_executive';
  static const String campaignExecutive = 'campaign_executive';
}

/// Authenticated user model
class CrmUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? title;
  final int monthlyLeadTarget;
  final int monthlyDealTarget;
  final double monthlyRevenueTarget;

  const CrmUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.phone,
    this.title,
    this.monthlyLeadTarget = 0,
    this.monthlyDealTarget = 0,
    this.monthlyRevenueTarget = 0,
  });

  factory CrmUser.fromJson(Map<String, dynamic> json) => CrmUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        title: json['title'] as String?,
        monthlyLeadTarget: (json['monthly_lead_target'] as num?)?.toInt() ?? 0,
        monthlyDealTarget: (json['monthly_deal_target'] as num?)?.toInt() ?? 0,
        monthlyRevenueTarget: (json['monthly_revenue_target'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar_url': avatarUrl,
        'phone': phone,
        'title': title,
        'monthly_lead_target': monthlyLeadTarget,
        'monthly_deal_target': monthlyDealTarget,
        'monthly_revenue_target': monthlyRevenueTarget,
      };

  bool get isAccountExecutive => role == UserRole.accountExecutive;
  bool get isCampaignExecutive => role == UserRole.campaignExecutive;

  bool get canEditLeads => isAccountExecutive;
  bool get canDeleteLeads => isAccountExecutive;
  bool get canChangeStatus => isAccountExecutive;
  bool get canReassignLeads => isAccountExecutive;
  bool get canCreateLeads => true;
  bool get canImportLeads => true;
  bool get canViewLeads => true;
  bool get canViewAnalytics => true;
  bool get canManageUsers => isAccountExecutive;
  bool get canAccessSettings => isAccountExecutive;
}

/// Authentication service backed by Supabase GoTrue
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static String get _serverBase => '${EnvConfig.apiBaseUrl}/api/auth';

  CrmUser? _user;
  StreamSubscription<AuthState>? _authSub;

  CrmUser? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Current Supabase access token (for server calls)
  String? get accessToken =>
      SupabaseConfig.auth.currentSession?.accessToken;

  /// Headers for authenticated API calls to our FastAPI server
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  // ── Lifecycle ──

  /// Call once at app startup to listen to Supabase auth state changes
  void init() {
    _authSub = SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      debugPrint('[Auth] event: $event');
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        await _loadProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        _user = null;
        notifyListeners();
      }
    });
  }

  /// Attempt to restore an existing session (Supabase persists it automatically)
  Future<bool> tryAutoLogin() async {
    final session = SupabaseConfig.auth.currentSession;
    if (session == null) return false;
    await _loadProfile();
    return _user != null;
  }

  // ── Login / Logout ──

  Future<CrmUser> login(String email, String password) async {
    try {
      await SupabaseConfig.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw CrmAuthException(e.message);
    } catch (e) {
      throw CrmAuthException(e.toString());
    }
    await _loadProfile();
    if (_user == null) {
      throw const CrmAuthException('Failed to load user profile');
    }
    return _user!;
  }

  /// Sign up with email, password, name, and role
  Future<CrmUser> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      await SupabaseConfig.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
        },
      );
    } on AuthException catch (e) {
      throw CrmAuthException(e.message);
    } catch (e) {
      throw CrmAuthException(e.toString());
    }
    await _loadProfile();
    if (_user == null) {
      throw const CrmAuthException('Account created — check your email to confirm, then sign in.');
    }
    return _user!;
  }

  Future<void> logout() async {
    try {
      await SupabaseConfig.auth.signOut();
    } catch (e) {
      debugPrint('[Auth] sign-out error: $e');
    }
    _user = null;
    notifyListeners();
  }

  /// Send a password-reset email via Supabase GoTrue.
  Future<void> resetPassword(String email) async {
    try {
      await SupabaseConfig.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw CrmAuthException(e.message);
    } catch (e) {
      throw CrmAuthException('Failed to send reset email: $e');
    }
  }

  // ── Profile ──

  Future<void> _loadProfile() async {
    final supaUser = SupabaseConfig.auth.currentUser;
    if (supaUser == null) return;

    final meta = supaUser.userMetadata ?? {};
    _user = CrmUser(
      id: supaUser.id,
      name: (meta['name'] as String?) ??
          supaUser.email?.split('@').first ??
          '',
      email: supaUser.email ?? '',
      role: (meta['role'] as String?) ?? UserRole.campaignExecutive,
      avatarUrl: meta['avatar_url'] as String?,
      phone: meta['phone'] as String?,
      title: meta['title'] as String?,
      monthlyLeadTarget: (meta['monthly_lead_target'] as num?)?.toInt() ?? 0,
      monthlyDealTarget: (meta['monthly_deal_target'] as num?)?.toInt() ?? 0,
      monthlyRevenueTarget: (meta['monthly_revenue_target'] as num?)?.toDouble() ?? 0,
    );
    notifyListeners();
  }

  /// Update the current user's profile metadata
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? title,
    String? avatarUrl,
    int? monthlyLeadTarget,
    int? monthlyDealTarget,
    double? monthlyRevenueTarget,
  }) async {
    // Build metadata — always include existing values to prevent data loss
    final existing = SupabaseConfig.auth.currentUser?.userMetadata ?? {};
    final meta = <String, dynamic>{...existing};
    if (name != null) meta['name'] = name;
    if (phone != null) meta['phone'] = phone;
    if (title != null) meta['title'] = title;
    if (avatarUrl != null) meta['avatar_url'] = avatarUrl;
    if (monthlyLeadTarget != null) meta['monthly_lead_target'] = monthlyLeadTarget;
    if (monthlyDealTarget != null) meta['monthly_deal_target'] = monthlyDealTarget;
    if (monthlyRevenueTarget != null) meta['monthly_revenue_target'] = monthlyRevenueTarget;

    try {
      debugPrint('[Auth] updateProfile: saving metadata: $meta');
      final response = await SupabaseConfig.auth.updateUser(
        UserAttributes(data: meta),
      );
      debugPrint('[Auth] updateProfile: response user id=${response.user?.id}');

      // Force session refresh to ensure latest metadata is persisted
      try {
        await SupabaseConfig.auth.refreshSession();
      } catch (e) {
        debugPrint('[Auth] refreshSession after update: $e');
      }

      // Reload profile from the refreshed session
      await _loadProfile();
      debugPrint('[Auth] updateProfile: success — name=${_user?.name}, avatar=${_user?.avatarUrl}');
    } on AuthException catch (e) {
      debugPrint('[Auth] updateProfile AuthException: ${e.message}');
      throw CrmAuthException(e.message);
    } catch (e) {
      debugPrint('[Auth] updateProfile error: $e');
      throw CrmAuthException('Failed to save profile: $e');
    }
  }

  /// Upload avatar image via server (bypasses Supabase RLS)
  Future<String> uploadAvatar(List<int> bytes, String fileName) async {
    final userId = _user?.id;
    if (userId == null) throw const CrmAuthException('Not authenticated');
    debugPrint('[Auth] uploadAvatar: uploading ${bytes.length} bytes as $fileName');
    try {
      // Determine content type from extension
      final ext = fileName.split('.').last.toLowerCase();
      String contentType = 'image/jpeg';
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'gif') contentType = 'image/gif';
      if (ext == 'webp') contentType = 'image/webp';

      // Upload via server (service_role key bypasses RLS)
      final b64 = base64Encode(bytes);
      final resp = await http.post(
        Uri.parse('$_serverBase/upload-avatar'),
        headers: authHeaders,
        body: jsonEncode({
          'file_data': b64,
          'file_name': fileName,
          'content_type': contentType,
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        final detail = resp.body;
        debugPrint('[Auth] uploadAvatar server error: $detail');
        throw CrmAuthException('Upload failed: $detail');
      }

      final body = jsonDecode(resp.body);
      final publicUrl = body['url'] as String;
      debugPrint('[Auth] uploadAvatar: publicUrl=$publicUrl');

      // Refresh session to pick up the updated avatar_url from metadata
      try {
        await SupabaseConfig.auth.refreshSession();
      } catch (e) {
        debugPrint('[Auth] refreshSession after avatar upload failed: $e');
      }
      await _loadProfile();

      return publicUrl;
    } catch (e) {
      debugPrint('[Auth] uploadAvatar error: $e');
      if (e is CrmAuthException) rethrow;
      throw CrmAuthException('Upload failed: $e');
    }
  }

  // ── KPI Targets (persisted in user_metadata) ──

  /// Load KPI targets from user_metadata
  List<Map<String, dynamic>> loadKpiTargets() {
    final meta = SupabaseConfig.auth.currentUser?.userMetadata ?? {};
    final raw = meta['kpi_targets'];
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Save KPI targets to user_metadata
  Future<void> saveKpiTargets(List<Map<String, dynamic>> targets) async {
    final existing = SupabaseConfig.auth.currentUser?.userMetadata ?? {};
    final meta = <String, dynamic>{...existing, 'kpi_targets': targets};
    try {
      debugPrint('[Auth] saveKpiTargets: saving ${targets.length} targets');
      await SupabaseConfig.auth.updateUser(UserAttributes(data: meta));
      await SupabaseConfig.auth.refreshSession();
      debugPrint('[Auth] saveKpiTargets: success');
    } on AuthException catch (e) {
      debugPrint('[Auth] saveKpiTargets error: ${e.message}');
      throw CrmAuthException(e.message);
    } catch (e) {
      debugPrint('[Auth] saveKpiTargets error: $e');
      throw CrmAuthException('Failed to save KPI targets: $e');
    }
  }

  // ── User management (Account Executive only, via FastAPI server) ──

  Future<List<CrmUser>> listUsers() async {
    final resp = await http
        .get(Uri.parse('$_serverBase/users'), headers: authHeaders)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return (body['users'] as List)
          .map((u) => CrmUser.fromJson(u as Map<String, dynamic>))
          .toList();
    }
    throw CrmAuthException(_extractError(resp));
  }

  Future<CrmUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_serverBase/users'),
          headers: authHeaders,
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'role': role,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return CrmUser.fromJson(body['user'] as Map<String, dynamic>);
    }
    throw CrmAuthException(_extractError(resp));
  }

  Future<void> deleteUser(String userId) async {
    final resp = await http
        .delete(Uri.parse('$_serverBase/users/$userId'),
            headers: authHeaders)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw CrmAuthException(_extractError(resp));
  }

  Future<CrmUser> updateUser(
    String userId, {
    String? name,
    String? email,
    String? role,
    String? password,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (email != null) data['email'] = email;
    if (role != null) data['role'] = role;
    if (password != null && password.isNotEmpty) data['password'] = password;
    final resp = await http
        .put(
          Uri.parse('$_serverBase/users/$userId'),
          headers: authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return CrmUser.fromJson(body['user'] as Map<String, dynamic>);
    }
    throw CrmAuthException(_extractError(resp));
  }

  String _extractError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      return (body['detail'] as String?) ?? 'Unknown error';
    } catch (_) {
      return 'Error ${resp.statusCode}';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class CrmAuthException implements Exception {
  final String message;
  const CrmAuthException(this.message);
  @override
  String toString() => message;
}
