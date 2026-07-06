import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gsheets/gsheets.dart';

/// Real Estate Bot Service
/// Handles communication between Flutter app and the AI calling bot backend
class RealEstateBotService {
  // Your Google Sheets credentials
  static const _credentials = r'''
  {
    "type": "service_account",
    "project_id": "your-project-id",
    "private_key_id": "your-private-key-id",
    "private_key": "your-private-key",
    "client_email": "your-service-account@your-project.iam.gserviceaccount.com",
    "client_id": "your-client-id",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
  }
  ''';

  static const _spreadsheetId = 'your-spreadsheet-id';
  static const _backendUrl = 'http://your-backend-url.com'; // Your deployed backend

  final GSheets _gsheets = GSheets(_credentials);
  Spreadsheet? _spreadsheet;

  /// Initialize connection to Google Sheets
  Future<void> initialize() async {
    try {
      _spreadsheet = await _gsheets.spreadsheet(_spreadsheetId);
      print('Connected to Google Sheets successfully');
    } catch (e) {
      print('Error connecting to Google Sheets: $e');
      rethrow;
    }
  }

  /// Submit new lead to Google Sheets
  Future<bool> submitLead({
    required String fullName,
    required String phoneNumber,
    required String location,
    required String propertyType,
    required String priceRange,
  }) async {
    try {
      if (_spreadsheet == null) await initialize();

      final sheet = _spreadsheet!.worksheetByTitle('Form Responses');
      if (sheet == null) {
        throw Exception('Form Responses sheet not found');
      }

      // Prepare row data
      final rowData = [
        DateTime.now().toIso8601String(),
        fullName,
        phoneNumber,
        location,
        propertyType,
        priceRange,
        'No', // Called status
      ];

      // Append row
      await sheet.values.appendRow(rowData);

      print('Lead submitted successfully: $fullName');

      // Trigger automated call after a delay
      _scheduleAutomatedCall(phoneNumber);

      return true;
    } catch (e) {
      print('Error submitting lead: $e');
      return false;
    }
  }

  /// Get leads from Google Sheets
  Future<List<Map<String, dynamic>>> getLeads() async {
    try {
      if (_spreadsheet == null) await initialize();

      final sheet = _spreadsheet!.worksheetByTitle('Form Responses');
      if (sheet == null) return [];

      final rows = await sheet.values.allRows();
      if (rows.isEmpty) return [];

      // First row is headers
      final headers = rows.first;
      final leads = <Map<String, dynamic>>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final lead = <String, dynamic>{};

        for (var j = 0; j < headers.length && j < row.length; j++) {
          lead[headers[j]] = row[j];
        }

        leads.add(lead);
      }

      return leads;
    } catch (e) {
      print('Error getting leads: $e');
      return [];
    }
  }

  /// Get properties from Google Sheets
  Future<List<Map<String, dynamic>>> getProperties({
    String? location,
    String? propertyType,
    String? priceRange,
  }) async {
    try {
      if (_spreadsheet == null) await initialize();

      final sheet = _spreadsheet!.worksheetByTitle('Properties');
      if (sheet == null) return [];

      final rows = await sheet.values.allRows();
      if (rows.isEmpty) return [];

      final headers = rows.first;
      var properties = <Map<String, dynamic>>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final property = <String, dynamic>{};

        for (var j = 0; j < headers.length && j < row.length; j++) {
          property[headers[j]] = row[j];
        }

        properties.add(property);
      }

      // Filter properties based on criteria
      if (location != null) {
        properties = properties.where((p) =>
        p['Location']?.toString().toLowerCase() == location.toLowerCase()
        ).toList();
      }

      if (propertyType != null) {
        properties = properties.where((p) =>
        p['Property Type']?.toString().toLowerCase() == propertyType.toLowerCase()
        ).toList();
      }

      if (priceRange != null) {
        properties = properties.where((p) =>
            _isInPriceRange(p['Price']?.toString() ?? '', priceRange)
        ).toList();
      }

      return properties;
    } catch (e) {
      print('Error getting properties: $e');
      return [];
    }
  }

  /// Get feedback/call results from Google Sheets
  Future<List<Map<String, dynamic>>> getFeedback() async {
    try {
      if (_spreadsheet == null) await initialize();

      final sheet = _spreadsheet!.worksheetByTitle('Feedback');
      if (sheet == null) return [];

      final rows = await sheet.values.allRows();
      if (rows.isEmpty) return [];

      final headers = rows.first;
      final feedback = <Map<String, dynamic>>[];

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        final item = <String, dynamic>{};

        for (var j = 0; j < headers.length && j < row.length; j++) {
          item[headers[j]] = row[j];
        }

        feedback.add(item);
      }

      return feedback;
    } catch (e) {
      print('Error getting feedback: $e');
      return [];
    }
  }

  /// Trigger automated call via backend
  void _scheduleAutomatedCall(String phoneNumber) {
    // Call will be triggered after 5 minutes
    Future.delayed(Duration(minutes: 5), () async {
      try {
        final response = await http.post(
          Uri.parse('$_backendUrl/trigger-call'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone_number': phoneNumber}),
        );

        if (response.statusCode == 200) {
          print('Automated call scheduled for $phoneNumber');
        } else {
          print('Failed to schedule call: ${response.body}');
        }
      } catch (e) {
        print('Error scheduling call: $e');
      }
    });
  }

  /// Check if price is in range
  bool _isInPriceRange(String price, String range) {
    final priceMap = {
      'Under ₹20 Lakhs': [0, 20],
      '₹20 - ₹40 Lakhs': [20, 40],
      '₹40 - ₹60 Lakhs': [40, 60],
      '₹60 - ₹80 Lakhs': [60, 80],
      '₹80 Lakhs - ₹1 Crore': [80, 100],
      'Above ₹1 Crore': [100, 999999],
    };

    if (!priceMap.containsKey(range)) return false;

    try {
      final priceNum = double.parse(
          price.replaceAll('₹', '').replaceAll('Lakhs', '').replaceAll('Crore', '').trim()
      );

      final actualPrice = price.contains('Crore') ? priceNum * 100 : priceNum;
      final rangeValues = priceMap[range]!;

      return actualPrice >= rangeValues[0] && actualPrice <= rangeValues[1];
    } catch (e) {
      return false;
    }
  }

  /// Manually trigger call for a specific lead
  Future<bool> triggerCall(String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/trigger-call'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error triggering call: $e');
      return false;
    }
  }

  /// Get call status
  Future<Map<String, dynamic>?> getCallStatus(String phoneNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/call-status/$phoneNumber'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting call status: $e');
      return null;
    }
  }
}