import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../config/app_config.dart';
import 'user/lead_form_screen.dart';
import 'user/properties_screen.dart';
import 'admin/admin_login_screen.dart';
import 'ngrok_setup_screen.dart';

/// Entry point — lets user choose between browsing listings, submitting an
/// inquiry, or logging in as admin.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  final String _titleFull = 'ESTAT·IQ';
  String _titleDisplay = '';
  int _charIndex = 0;
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 20, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 200), _startTypewriter);
  }

  void _startTypewriter() {
    _typeTimer = Timer.periodic(const Duration(milliseconds: 90), (t) {
      if (_charIndex >= _titleFull.length) {
        t.cancel();
        _controller.forward();
        return;
      }
      setState(() => _titleDisplay = _titleFull.substring(0, ++_charIndex));
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Logo & title ─────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        _titleDisplay,
                        style: AppText.displayLarge.copyWith(
                          color: AppColors.gold,
                          fontSize: 38,
                        ),
                      ),
                      if (_charIndex < _titleFull.length) _BlinkingCursor(),
                    ]),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _fadeAnim,
                      builder: (_, child) => Opacity(
                        opacity: _fadeAnim.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnim.value),
                          child: child,
                        ),
                      ),
                      child: Text(
                        'AI-Powered Property Intelligence',
                        style: AppText.mono(
                          size: 13,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, child) =>
                    Opacity(opacity: _fadeAnim.value, child: child),
                child: const Divider(color: AppColors.border, thickness: 1),
              ),

              const SizedBox(height: 48),

              // ── CTAs ──────────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, child) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value * 1.5),
                    child: child,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '— SELECT MODE',
                      style: AppText.label
                          .copyWith(color: AppColors.textMuted, letterSpacing: 3),
                    ),
                    const SizedBox(height: 24),

                    // ── Primary: Submit Inquiry ──────────────────────────
                    _RetroButton(
                      label: 'SUBMIT INQUIRY',
                      icon: Icons.search_outlined,
                      filled: true,
                      onTap: () => Navigator.push(
                        context,
                        _fadeRoute(const LeadFormScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Secondary: Browse Properties ─────────────────────
                    _RetroButton(
                      label: 'BROWSE LISTINGS',
                      icon: Icons.apartment_outlined,
                      filled: false,
                      onTap: () => Navigator.push(
                        context,
                        _fadeRoute(const PropertiesScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Tertiary: Admin ──────────────────────────────────
                    _RetroButton(
                      label: '[ ADMIN PANEL ]',
                      icon: Icons.admin_panel_settings_outlined,
                      filled: false,
                      dim: true,
                      onTap: () => Navigator.push(
                        context,
                        _fadeRoute(const AdminLoginScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),

              // ── Footer ────────────────────────────────────────────────────
              AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, child) =>
                    Opacity(opacity: _fadeAnim.value * 0.5, child: child),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      // Backend status row
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          _fadeRoute(const NgrokSetupScreen(isFirstRun: false)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppConfig.isNgrokConfigured
                                    ? AppColors.statusAppointedText
                                    : AppColors.errorText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppConfig.isNgrokConfigured
                                  ? 'BACKEND: ${AppConfig.ngrokBase.replaceFirst('https://', '')}'
                                  : 'BACKEND: NOT CONFIGURED — TAP TO SETUP',
                              style: AppText.caption.copyWith(
                                color: AppConfig.isNgrokConfigured
                                    ? AppColors.statusAppointedText
                                    : AppColors.errorText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 6, height: 6, color: AppColors.goldDim),
                          const SizedBox(width: 10),
                          Text(
                            'Powered by n8n · Bland.ai · Google Sheets',
                            style: AppText.caption,
                          ),
                          const SizedBox(width: 10),
                          Container(
                              width: 6, height: 6, color: AppColors.goldDim),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Text('▌',
            style: AppText.displayLarge
                .copyWith(color: AppColors.gold, fontSize: 38)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _RetroButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final bool dim;
  final VoidCallback onTap;

  const _RetroButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.dim = false,
  });

  @override
  State<_RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<_RetroButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHot = widget.filled || _hovered;
    final borderColor = widget.dim
        ? AppColors.borderMid
        : (isHot ? AppColors.gold : AppColors.borderMid);
    final bgColor = widget.filled
        ? AppColors.gold
        : (_hovered ? AppColors.gold.withOpacity(0.07) : Colors.transparent);
    final textColor = (widget.filled || (widget.filled && _hovered))
        ? AppColors.background
        : (widget.dim ? AppColors.textMuted : AppColors.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: 14,
                    color: widget.filled
                        ? AppColors.background
                        : AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: AppText.mono(
                  size: 12,
                  color: textColor,
                  weight: widget.filled ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
