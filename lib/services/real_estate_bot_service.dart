import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// RealEstateBotService — thin wrapper that delegates to the Python backend.
///
/// Write path: Flutter → ngrok → server.py → Google Sheets + Twilio + Bland.ai
///
/// This service is used by the legacy LeadSubmissionScreen.  The primary
/// user-facing form (LeadFormScreen) uses WebhookService directly.
class RealEstateBotService {
  /// Initialize — nothing to do (backend handles all side-effects).
  Future<void> init() async {}

  Future<bool> submitLead({
    required String fullName,
    required String phoneNumber,
    required String location,
    required String propertyType,
    required String priceRange,
  }) async {
    try {
      final url = AppConfig.webhookNewLead;
      final body = {
        'full_name':     fullName,
        'phone':         phoneNumber,
        'location':      location,
        'property_type': propertyType,
        'price_range':   priceRange,
        'source':        'flutter_app',
      };

      final res = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      print('[RealEstateBotService] submitLead error: $e');
      return false;
    }
  }
}
