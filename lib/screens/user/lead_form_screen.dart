import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/webhook_service.dart';
import '../ngrok_setup_screen.dart';

class LeadFormScreen extends StatefulWidget {
  /// Pre-filled when navigating from a property card.
  final String? prefilledType;
  final String? prefilledLocation;

  const LeadFormScreen({
    super.key,
    this.prefilledType,
    this.prefilledLocation,
  });

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _location, _propertyType, _priceRange;
  bool _submitting = false;
  bool _showSuccess = false;

  static const _locations = [
    'Pune', 'Nagpur', 'Nanded', 'Mumbai', 'Nashik', 'Aurangabad',
  ];
  static const _types = [
    'Flat', 'House', 'Plot', 'Shop', 'Villa', 'Office',
  ];
  static const _budgets = [
    'Under ₹20 Lakhs',
    '₹20 – ₹40 Lakhs',
    '₹40 – ₹60 Lakhs',
    '₹60 – ₹80 Lakhs',
    '₹80 Lakhs – ₹1 Crore',
    'Above ₹1 Crore',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill from properties screen if provided
    if (widget.prefilledType != null) {
      final match = _types.firstWhere(
        (t) => t.toLowerCase() == widget.prefilledType!.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) _propertyType = match;
    }
    if (widget.prefilledLocation != null) {
      final match = _locations.firstWhere(
        (l) => l.toLowerCase() == widget.prefilledLocation!.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) _location = match;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // Send to Python backend via ngrok.
    // Backend writes to Sheet1 + sends Twilio SMS + fires Bland.ai call.
    final error = await WebhookService.instance.submitLead(
      fullName:     _nameCtrl.text.trim(),
      phone:        _phoneCtrl.text.trim(),
      location:     _location!,
      propertyType: _propertyType!,
      priceRange:   _priceRange!,
    );

    setState(() => _submitting = false);

    if (error == null) {
      _clearForm();
      setState(() => _showSuccess = true);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ERROR: $error',
            style: AppText.mono(size: 11, color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'SETUP',
            textColor: Colors.white,
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => NgrokSetupScreen(isFirstRun: false)));
            },
          ),
        ),
      );
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    setState(() {
      _location = null;
      _propertyType = null;
      _priceRange = null;
    });
    _formKey.currentState?.reset();
  }

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
        title: Text('PROPERTY INQUIRY', style: AppText.heading),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pre-fill notice
                  if (widget.prefilledType != null ||
                      widget.prefilledLocation != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.05),
                        border: Border.all(color: AppColors.goldDim),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '✓  Pre-filled from your selected property',
                        style: AppText.mono(
                            size: 11, color: AppColors.gold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text(
                    'Tell us what you\'re looking for.\nOur AI will call you within 5 minutes.',
                    style: AppText.bodySmall.copyWith(height: 1.8),
                  ),
                  const SizedBox(height: 36),

                  _Label('FULL NAME'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameCtrl,
                    style: AppText.body,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'e.g. Rahul Sharma'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  _Label('PHONE NUMBER'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _phoneCtrl,
                    style: AppText.body,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: '10-digit mobile number',
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 10) return 'Must be exactly 10 digits';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  _Label('PREFERRED LOCATION'),
                  const SizedBox(height: 6),
                  _Dropdown<String>(
                    value: _location,
                    hint: 'Select city',
                    items: _locations,
                    onChanged: (v) => setState(() => _location = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  _Label('PROPERTY TYPE'),
                  const SizedBox(height: 6),
                  _Dropdown<String>(
                    value: _propertyType,
                    hint: 'Flat / House / Plot …',
                    items: _types,
                    onChanged: (v) => setState(() => _propertyType = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),

                  _Label('BUDGET RANGE'),
                  const SizedBox(height: 6),
                  _Dropdown<String>(
                    value: _priceRange,
                    hint: 'Select range',
                    items: _budgets,
                    onChanged: (v) => setState(() => _priceRange = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),

                  const SizedBox(height: 40),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _submitting
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
                            onTap: _submit,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'SUBMIT INQUIRY',
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
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '· AI call within 5 minutes ·',
                      style: AppText.caption.copyWith(
                        color: AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          if (_showSuccess)
            _SuccessOverlay(
              onDone: () {
                setState(() => _showSuccess = false);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.label.copyWith(letterSpacing: 2.5));
}

class _Dropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;

  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: AppColors.surfaceElevated,
      style: AppText.body,
      icon: const Icon(
          Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.mono(size: 13, color: AppColors.textMuted),
      ),
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text(e.toString(), style: AppText.body),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class _SuccessOverlay extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessOverlay({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gold),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: AppColors.gold, size: 24),
              ),
              const SizedBox(height: 32),
              Text(
                'INQUIRY\nSUBMITTED.',
                style: AppText.displayMedium.copyWith(height: 1.25),
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border),
              const SizedBox(height: 20),
              Text(
                'Your details have been saved.\n\n'
                'Our AI assistant will call you within the next 5 minutes '
                'to discuss available properties matching your requirements.',
                style: AppText.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: onDone,
                child: Text(
                  '← BACK',
                  style: AppText.mono(
                    size: 12,
                    color: AppColors.gold,
                    letterSpacing: 2,
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
