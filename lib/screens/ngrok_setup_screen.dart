import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';
import '../services/webhook_service.dart';
import '../theme/app_theme.dart';
import 'splash_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// NgrokSetupScreen
///
/// Shown on first launch (or when backend is unreachable).
/// User pastes their ngrok HTTPS URL and we verify it with a /health ping.
/// On success → navigates to SplashScreen.
/// ─────────────────────────────────────────────────────────────────────────────
class NgrokSetupScreen extends StatefulWidget {
  /// If true, this is a first-run setup; if false, user came here from a
  /// "change backend URL" settings option.
  final bool isFirstRun;
  const NgrokSetupScreen({super.key, this.isFirstRun = true});

  @override
  State<NgrokSetupScreen> createState() => _NgrokSetupScreenState();
}

class _NgrokSetupScreenState extends State<NgrokSetupScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  _Status _status = _Status.idle;
  String _statusMsg = '';
  Map<String, dynamic>? _diagResults;
  bool _diagLoading = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // Pre-fill existing URL if available
    if (AppConfig.isNgrokConfigured) {
      _ctrl.text = AppConfig.ngrokBase;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      _setStatus(_Status.error, 'Please paste your ngrok URL.');
      return;
    }
    final url = raw.replaceAll(RegExp(r'/$'), '');
    if (!url.startsWith('https://')) {
      _setStatus(_Status.error,
          'URL must start with https://\nExample: https://xxxx.ngrok-free.app');
      return;
    }

    _setStatus(_Status.checking, 'Connecting to backend…');
    AppConfig.setNgrokBase(url);

    final ok = await WebhookService.instance.checkHealth();
    if (!mounted) return;

    if (ok) {
      _setStatus(_Status.success, 'Backend connected ✓');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SplashScreen(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
        (_) => false,
      );
    } else {
      _setStatus(_Status.error,
          'Could not reach backend.\n\n'
          '• Is server.py running?  (python backend/server.py)\n'
          '• Is ngrok running?      (ngrok http 5000)\n'
          '• Did you paste the correct https:// URL?');
    }
  }

  Future<void> _runDiagnostic() async {
    final url = _ctrl.text.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty || !url.startsWith('https://')) {
      _setStatus(_Status.error, 'Paste an ngrok URL first.');
      return;
    }
    AppConfig.setNgrokBase(url);
    
    setState(() { _diagLoading = true; _diagResults = null; });
    final res = await WebhookService.instance.runDiagnostic();
    setState(() { _diagResults = res; _diagLoading = false; });
    
    if (res == null) {
      _setStatus(_Status.error, 'Diagnostic failed to reach backend.');
    }
  }

  Future<void> _runIndividualTest(String type) async {
    final phone = _diagResults?['sheets']?['status'] == 'OK' ? '9876543210' : ''; // dummy if sheet not ready
    // We'll just ask WebhookService to do it
    final url = AppConfig.ngrokBase;
    if (url.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting $type test...', style: AppText.mono(size: 11))),
    );

    bool ok = false;
    if (type == 'sms') {
      ok = await WebhookService.instance.testSms('9876543210'); // using dummy for testing integration
    } else {
      ok = await WebhookService.instance.testCall('9876543210');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '$type test triggered! Check your phone.' : '$type test failed.', style: AppText.mono(size: 11)),
        backgroundColor: ok ? AppColors.statusAppointed : AppColors.error,
      ),
    );
  }

  void _skip() {
    // Allow skipping — app works for browse/admin even without backend
    AppConfig.setNgrokBase(_ctrl.text.trim().isEmpty
        ? 'https://placeholder.ngrok-free.app'
        : _ctrl.text.trim());
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
      (_) => false,
    );
  }

  void _setStatus(_Status s, String msg) =>
      setState(() { _status = s; _statusMsg = msg; });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title ──────────────────────────────────────────────────
                Text('ESTAT·IQ',
                    style: AppText.displayLarge
                        .copyWith(color: AppColors.gold, fontSize: 28)),
                const SizedBox(height: 6),
                Text('Backend Setup',
                    style: AppText.mono(
                        size: 12,
                        color: AppColors.textSecondary,
                        letterSpacing: 1)),

                const SizedBox(height: 40),
                const Divider(color: AppColors.border),
                const SizedBox(height: 32),

                // ── Instructions ──────────────────────────────────────────
                Text('CONNECT BACKEND',
                    style: AppText.label.copyWith(
                        letterSpacing: 3, color: AppColors.textMuted)),
                const SizedBox(height: 20),

                _StepRow(
                  step: '1',
                  label: 'Start the Python server',
                  command: 'python backend/server.py',
                ),
                const SizedBox(height: 12),
                _StepRow(
                  step: '2',
                  label: 'Start ngrok tunnel',
                  command: 'ngrok http 5000',
                ),
                const SizedBox(height: 12),
                _StepRow(
                  step: '3',
                  label: 'Copy the  https://xxxx.ngrok-free.app  URL below',
                  command: null,
                ),

                const SizedBox(height: 32),

                // ── URL Input ─────────────────────────────────────────────
                Text('NGROK URL',
                    style: AppText.label.copyWith(letterSpacing: 2.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: AppText.mono(size: 12),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'https://xxxx.ngrok-free.app',
                          hintStyle:
                              AppText.mono(size: 12, color: AppColors.textMuted),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear,
                                size: 14, color: AppColors.textMuted),
                            onPressed: () => _ctrl.clear(),
                          ),
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Status ───────────────────────────────────────────────
                if (_statusMsg.isNotEmpty) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _status == _Status.success
                          ? AppColors.statusAppointed.withOpacity(0.15)
                          : _status == _Status.error
                              ? AppColors.error.withOpacity(0.12)
                              : AppColors.surfaceElevated,
                      border: Border.all(
                        color: _status == _Status.success
                            ? AppColors.statusAppointedText.withOpacity(0.4)
                            : _status == _Status.error
                                ? AppColors.error.withOpacity(0.5)
                                : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_status == _Status.checking)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.2,
                              color: AppColors.gold,
                            ),
                          )
                        else
                          Icon(
                            _status == _Status.success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 14,
                            color: _status == _Status.success
                                ? AppColors.statusAppointedText
                                : AppColors.errorText,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMsg,
                            style: AppText.mono(
                              size: 11,
                              color: _status == _Status.success
                                  ? AppColors.statusAppointedText
                                  : _status == _Status.error
                                      ? AppColors.errorText
                                      : AppColors.textSecondary,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Connect Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _status == _Status.checking
                      ? Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.gold,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _verify,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'CONNECT & VERIFY',
                              style: AppText.mono(
                                size: 13,
                                color: AppColors.background,
                                weight: FontWeight.w500,
                                letterSpacing: 2.5,
                              ),
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 12),

                // ── Diagnostic Results ─────────────────────────────────────
                if (_diagResults != null || _diagLoading) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SYSTEM DIAGNOSTIC', style: AppText.label.copyWith(letterSpacing: 2, fontSize: 10)),
                        const SizedBox(height: 16),
                        if (_diagLoading)
                          const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
                        else ...[
                          _DiagRow(label: 'Google Sheets Access', status: _diagResults!['sheets']),
                          _DiagRow(label: 'Sheet Tab Structure', status: _diagResults!['sheet_naming']),
                          _DiagRow(label: 'Twilio API', status: _diagResults!['twilio']),
                          _DiagRow(label: 'Bland.ai API', status: _diagResults!['bland_ai']),
                          
                          if (_diagResults!['sheets']?['status'] != 'OK') ...[
                            const SizedBox(height: 12),
                            Text(
                              'HELP: Make sure you shared the sheet with\nreal-estate-bot@lexo-agent.iam.gserviceaccount.com as Editor.',
                              style: AppText.mono(size: 9, color: AppColors.goldDim),
                            ),
                          ],
                          
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.border),
                          ),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _SmallButton(
                                  label: 'TEST SMS',
                                  onPressed: () => _runIndividualTest('sms'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SmallButton(
                                  label: 'TEST CALL',
                                  onPressed: () => _runIndividualTest('call'),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Diagnostic Trigger ─────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _diagLoading ? null : _runDiagnostic,
                    child: Text(
                      _diagLoading ? 'RUNNING...' : '⚡ RUN COMPREHENSIVE DIAGNOSTIC',
                      style: AppText.mono(
                        size: 11,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Skip ─────────────────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _skip,
                    child: Text(
                      'SKIP — Browse listings / Admin only',
                      style: AppText.mono(
                        size: 10,
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                const Divider(color: AppColors.border),
                const SizedBox(height: 20),

                // ── Info footer ───────────────────────────────────────────
                Text(
                  'The backend handles Google Sheets writes, Twilio SMS, '
                  'and Bland.ai calls.  The ngrok URL changes every time you '
                  'restart ngrok (unless you have a paid static domain).',
                  style: AppText.caption.copyWith(
                      color: AppColors.textMuted, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step row ────────────────────────────────────────────────────────────────
class _StepRow extends StatelessWidget {
  final String step;
  final String label;
  final String? command;
  const _StepRow({required this.step, required this.label, this.command});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.goldDim),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(step,
              style:
                  AppText.mono(size: 9, color: AppColors.gold, letterSpacing: 0)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      AppText.mono(size: 11, color: AppColors.textSecondary)),
              if (command != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    command!,
                    style: AppText.mono(
                        size: 11,
                        color: AppColors.gold.withOpacity(0.85),
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? status;
  const _DiagRow({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status?['status'] ?? 'UNKNOWN';
    final err = status?['error'];
    final isOk = s == 'OK';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: isOk ? AppColors.statusAppointedText : AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label: $s',
                  style: AppText.mono(
                    size: 11,
                    color: isOk ? AppColors.textSecondary : AppColors.errorText,
                  ),
                ),
              ),
            ],
          ),
          if (!isOk && err != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                err.toString(),
                style: AppText.mono(size: 9, color: AppColors.errorText.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SmallButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: AppText.mono(size: 9, color: AppColors.textSecondary, weight: FontWeight.w600, letterSpacing: 1),
        ),
      ),
    );
  }
}

enum _Status { idle, checking, success, error }
