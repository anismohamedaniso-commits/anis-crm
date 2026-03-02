import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/services/auth_service.dart';
import 'package:anis_crm/components/brand_logo.dart';
import 'package:anis_crm/theme.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _success;
  String _role = 'campaign_executive'; // Default role — admins promote via team page

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    // Validate email format
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await AuthService.instance.signUp(
        email: email,
        password: password,
        name: name,
        role: _role,
      );
      if (mounted) context.go('/app/dashboard');
    } on CrmAuthException catch (e) {
      if (e.message.contains('check your email') ||
          e.message.contains('confirm')) {
        setState(() => _success = e.message);
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
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
      backgroundColor:
          isDark ? const Color(0xFF0A0C10) : const Color(0xFFF5F5F3),
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
                            color: Colors.white
                                .withValues(alpha: isDark ? 0.08 : 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                              child: BrandMark(size: 56, showText: false)),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Join the Tick&Talk Sales Team',
                            style: tt.labelSmall?.withColor(Colors.white.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Sign-up form ──
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
                              child: const Center(
                                  child: BrandMark(size: 38, showText: false)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: Text('Tick&Talk CRM', style: tt.headlineSmall?.semiBold),
                          ),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          'Create account',
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Get started with Tick&Talk CRM',
                          style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 28),

                        // Full Name
                        _label(tt, cs, 'Full Name'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          style: tt.bodyMedium,
                          decoration: _inputDecoration(
                              context, 'Anis Arafa', Icons.person_outlined),
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _label(tt, cs, 'Email'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: tt.bodyMedium,
                          decoration: _inputDecoration(context,
                              'you@tickandtalk.com', Icons.email_outlined),
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        _label(tt, cs, 'Password'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.next,
                          style: tt.bodyMedium,
                          decoration: _inputDecoration(context,
                                  'Min 6 characters', Icons.lock_outlined)
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color:
                                      cs.onSurface.withValues(alpha: 0.4)),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        _label(tt, cs, 'Confirm Password'),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          style: tt.bodyMedium,
                          decoration: _inputDecoration(context,
                                  'Re-enter password', Icons.lock_outlined)
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color:
                                      cs.onSurface.withValues(alpha: 0.4)),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 20),

                        // Role selector
                        const SizedBox(height: 24),

                        // Error message
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: cs.error.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    size: 18, color: cs.error),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_error!, style: tt.bodySmall?.withColor(cs.error)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Success message
                        if (_success != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18, color: AppColors.success),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(_success!, style: tt.bodySmall?.withColor(AppColors.success)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Sign Up button
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: tt.titleSmall?.semiBold,
                            ),
                            child: _loading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: cs.onPrimary),
                                  )
                                : const Text('Create Account'),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sign in link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.5)),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Sign In',
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

  Widget _label(TextTheme tt, ColorScheme cs, String text) => Text(
        text,
        style: tt.labelMedium?.medium.withColor(cs.onSurface.withValues(alpha: 0.7)),
      );

  Widget _roleCard({
    required ColorScheme cs,
    required TextTheme tt,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final selected = _role == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _role = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.1)
                : isDark
                    ? cs.surface.withValues(alpha: 0.5)
                    : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 28,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.5)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: tt.labelMedium?.semiBold.withColor(selected ? cs.primary : cs.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      BuildContext context, String hint, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.3)),
      prefixIcon:
          Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
      filled: true,
      fillColor:
          isDark ? cs.surface.withValues(alpha: 0.5) : cs.surfaceContainerLowest,
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
