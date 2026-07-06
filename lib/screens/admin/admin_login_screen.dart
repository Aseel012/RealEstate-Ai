import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _authenticate() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    // Simulate a tiny delay for UX feel
    await Future.delayed(const Duration(milliseconds: 600));

    final emailOk =
        _emailController.text.trim() == AppConfig.adminEmail;
    final passOk = _passwordController.text == AppConfig.adminPassword;

    if (emailOk && passOk) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AdminDashboardScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } else {
      setState(() {
        _error = 'Invalid credentials';
        _loading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────
                  Text(
                    'ADMIN\nACCESS',
                    style: AppText.displayMedium.copyWith(height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Authenticated access only.',
                    style: AppText.bodySmall,
                  ),
                  const SizedBox(height: 40),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 36),

                  // ── Email ───────────────────────────────────────
                  Text('EMAIL', style: AppText.label.copyWith(letterSpacing: 2.5)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    style: AppText.body,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'admin@domain.com',
                      hintStyle: AppText.mono(size: 13, color: AppColors.textMuted),
                    ),
                    onSubmitted: (_) => _authenticate(),
                  ),
                  const SizedBox(height: 24),

                  // ── Password ────────────────────────────────────
                  Text('PASSWORD', style: AppText.label.copyWith(letterSpacing: 2.5)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    style: AppText.body,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: AppText.mono(size: 13, color: AppColors.textMuted),
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _authenticate(),
                  ),

                  // ── Error ───────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.errorText, size: 14),
                        const SizedBox(width: 8),
                        Text(_error!,
                            style: AppText.mono(
                                size: 11, color: AppColors.errorText)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 36),

                  // ── Auth Button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _loading
                        ? Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.gold,
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: _authenticate,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.gold),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'AUTHENTICATE →',
                                style: AppText.mono(
                                  size: 12,
                                  color: AppColors.gold,
                                  weight: FontWeight.w500,
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
