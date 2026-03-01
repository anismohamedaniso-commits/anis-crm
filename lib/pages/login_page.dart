import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/components/brand_logo.dart';
import 'package:anis_crm/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password');
      return;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.login(email, password);
      if (mounted) context.go('/app/dashboard');
    } on CrmAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Connection failed. Is the server running?');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW >= 900;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0C10) : const Color(0xFFF5F5F3),
      body: Row(
        children: [
          // ── Left brand panel (wide screens) ──
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                      ? [const Color(0xFF1A0E08), const Color(0xFF0F1115)]
                      : [const Color(0xFFFF8A50), const Color(0xFFE8572A)],
                  ),
                ),
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(child: BrandMark(size: 56, showText: false)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Tick&Talk CRM',
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sales Management Platform',
                          style: tt.bodyMedium?.withColor(Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Designed by ANIS for Tick&Talk Sales',
                            style: tt.labelSmall?.withColor(Colors.white.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Login form ──
          Expanded(
            flex: isWide ? 4 : 1,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 60 : 32,
                  vertical: 40,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isWide) ...[
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(child: BrandMark(size: 38, showText: false)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text('Tick&Talk CRM', style: tt.headlineSmall?.semiBold),
                          ),
                          const SizedBox(height: 32),
                        ],

                        Text(
                          'Welcome back',
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to your account',
                          style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 32),

                        // Email
                        Text('Email', style: tt.labelMedium?.medium.withColor(cs.onSurface.withValues(alpha: 0.7))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: tt.bodyMedium,
                          decoration: _inputDecoration(context, 'you@tickandtalk.com', Icons.email_outlined),
                          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 18),

                        // Password
                        Text('Password', style: tt.labelMedium?.medium.withColor(cs.onSurface.withValues(alpha: 0.7))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          style: tt.bodyMedium,
                          decoration: _inputDecoration(context, 'Enter password', Icons.lock_outlined).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 24),

                        // Error
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cs.error.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 18, color: cs.error),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_error!, style: tt.bodySmall?.withColor(cs.error)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Sign in button
                        SizedBox(
                          height: 48,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.primary,
                                foregroundColor: cs.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                textStyle: tt.titleSmall?.semiBold,
                                disabledBackgroundColor: cs.primary.withValues(alpha: 0.7),
                              ),
                              child: _loading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('Signing in...', style: TextStyle(color: cs.onPrimary)),
                                      ],
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Forgot password link
                        Align(
                          alignment: Alignment.centerRight,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _showForgotPasswordDialog(context),
                              child: Text(
                                'Forgot password?',
                                style: tt.bodySmall?.withColor(cs.primary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.5)),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.go('/signup'),
                                child: Text(
                                  'Sign Up',
                                  style: tt.bodySmall?.semiBold.withColor(cs.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext ctx) {
    final resetEmailCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dialogCtx) {
        final cs = Theme.of(dialogCtx).colorScheme;
        final tt = Theme.of(dialogCtx).textTheme;
        return AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your account email and we\u2019ll send a password-reset link.',
                style: tt.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'you@tickandtalk.com',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final email = resetEmailCtrl.text.trim();
                if (email.isEmpty) return;
                Navigator.of(dialogCtx).pop();
                try {
                  await AuthService.instance.resetPassword(email);
                  if (mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Password-reset email sent to $email'),
                        backgroundColor: cs.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: cs.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
      filled: true,
      fillColor: isDark ? cs.surface.withValues(alpha: 0.5) : cs.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    );
  }
}
