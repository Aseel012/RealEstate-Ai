import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Sends data to the local Python backend exposed via ngrok.
///
/// Backend handles: Google Sheets write + Twilio SMS + Bland.ai call.
/// All in one POST — Flutter just submits and gets 200 back quickly.
class WebhookService {
  WebhookService._();
  static final WebhookService instance = WebhookService._();

  // ─── Submit a new lead ────────────────────────────────────────────────────
  Future<String?> submitLead({
    required String fullName,
    required String phone,
    required String location,
    required String propertyType,
    required String priceRange,
  }) =>
      _postWithErrorMessage(AppConfig.webhookNewLead, {
        'full_name':     fullName,
        'phone':         phone,
        'location':      location,
        'property_type': propertyType,
        'price_range':   priceRange,
        'timestamp':     DateTime.now().toIso8601String(),
        'source':        'flutter_app',
      });

  // ─── Manually trigger a call ──────────────────────────────────────────────
  Future<bool> triggerCall({
    required String phone,
    required String fullName,
  }) =>
      _post(AppConfig.webhookTriggerCall, {
        'phone_number': phone,
        'full_name':    fullName,
      });

  // ─── Book an appointment ──────────────────────────────────────────────────
  Future<bool> bookAppointment({
    required String fullName,
    required String phone,
    required String appointmentDate,
    required String appointmentTime,
    required String location,
    required String propertyType,
    required String budget,
    String notes = '',
  }) =>
      _post(AppConfig.webhookBookAppointment, {
        'full_name':         fullName,
        'phone':             phone,
        'appointment_date':  appointmentDate,
        'appointment_time':  appointmentTime,
        'location':          location,
        'property_type':     propertyType,
        'budget':            budget,
        'notes':             notes,
      });

  // ─── Health check ─────────────────────────────────────────────────────────
  Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.webhookHealth),
              headers: {'ngrok-skip-browser-warning': 'true'})
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Run comprehensive diagnostic ─────────────────────────────────────────
  Future<Map<String, dynamic>?> runDiagnostic() async {
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.ngrokBase}/diagnostic'),
              headers: {'ngrok-skip-browser-warning': 'true'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[Webhook] Diagnostic failure: $e');
    }
    return null;
  }

  // ─── Test SMS ─────────────────────────────────────────────────────────────
  Future<bool> testSms(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.ngrokBase}/test-sms'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ─── Test Call ────────────────────────────────────────────────────────────
  Future<bool> testCall(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.ngrokBase}/test-call'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({'phone': phone}),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  // ─── Internal POST ────────────────────────────────────────────────────────
  Future<bool> _post(String url, Map<String, dynamic> body) async {
    final err = await _postWithErrorMessage(url, body);
    return err == null;
  }

  // ─── Internal POST with Error Body ─────────────────────────────────────────
  Future<String?> _postWithErrorMessage(String url, Map<String, dynamic> body) async {
    try {
      print('[Webhook] POST → $url');
      print('[Webhook] Body: ${jsonEncode(body)}');

      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      print('[Webhook] ← HTTP ${res.statusCode}');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        print('[Webhook] SUCCESS: ${res.body.substring(0, res.body.length.clamp(0, 100))}...');
        return null;
      } else {
        try {
          final data = jsonDecode(res.body);
          final msg = data['error'] ?? data['message'] ?? 'Status ${res.statusCode}';
          print('[Webhook] SERVER ERROR: $msg');
          return msg.toString();
        } catch (_) {
          return 'Server Error ${res.statusCode}';
        }
      }
    } catch (e) {
      print('[Webhook] NETWORK ERROR: $e');
      return 'Network error: $e';
    }
  }
}
