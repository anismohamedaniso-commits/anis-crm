// Authentication Manager - Base interface for auth implementations
//
// This abstract class and mixins define the contract for authentication systems.
// Implement this with concrete classes for Firebase, Supabase, or local auth.
//
// Usage:
// 1. Create a concrete class extending AuthManager
// 2. Mix in the required authentication provider mixins
// 3. Implement all abstract methods with your auth provider logic

import 'package:flutter/material.dart';

// Generic user handle for auth providers. Concrete implementations can map this
// to their specific user type (e.g., SupabaseUser). We intentionally avoid a
// hard dependency so this file compiles before an auth provider is wired.
typedef AuthUser = Object;

// Core authentication operations that all auth implementations must provide
abstract class AuthManager {
  Future signOut();
  Future deleteUser(BuildContext context);
  Future updateEmail({required String email, required BuildContext context});
  Future resetPassword({required String email, required BuildContext context});
  Future sendEmailVerification({required AuthUser user});
  Future refreshUser({required AuthUser user});
}

// Email/password authentication mixin
mixin EmailSignInManager on AuthManager {
  Future<AuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  );

  Future<AuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  );
}

// Anonymous authentication for guest users
mixin AnonymousSignInManager on AuthManager {
  Future<AuthUser?> signInAnonymously(BuildContext context);
}

// Apple Sign-In authentication (iOS/web)
mixin AppleSignInManager on AuthManager {
  Future<AuthUser?> signInWithApple(BuildContext context);
}

// Google Sign-In authentication (all platforms)
mixin GoogleSignInManager on AuthManager {
  Future<AuthUser?> signInWithGoogle(BuildContext context);
}

// JWT token authentication for custom backends
mixin JwtSignInManager on AuthManager {
  Future<AuthUser?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  );
}

// Phone number authentication with SMS verification
mixin PhoneSignInManager on AuthManager {
  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  });

  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  });
}

// Facebook Sign-In authentication
mixin FacebookSignInManager on AuthManager {
  Future<AuthUser?> signInWithFacebook(BuildContext context);
}

// Microsoft Sign-In authentication (Azure AD)
mixin MicrosoftSignInManager on AuthManager {
  Future<AuthUser?> signInWithMicrosoft(
    BuildContext context,
    List<String> scopes,
    String tenantId,
  );
}

// GitHub Sign-In authentication (OAuth)
mixin GithubSignInManager on AuthManager {
  Future<AuthUser?> signInWithGithub(BuildContext context);
}
