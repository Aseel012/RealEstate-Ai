import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/lead_model.dart';
import '../models/property_model.dart';
import '../models/calling_record.dart';
import '../models/appointment.dart';

/// Reads from Google Sheets using the Sheets API v4 REST endpoint + API key.
///
/// READ-ONLY — requires NO service account.
/// Spreadsheet must be shared as "Anyone with the link → Viewer".
class SheetsReader {
  SheetsReader._();

  static const _base = 'https://sheets.googleapis.com/v4/spreadsheets';

  // ─── Generic reader ────────────────────────────────────────────────────────
  static Future<List<T>> _readSheet<T>({
    required String sheetTab,
    required String range,
    required T Function(List<String>) parser,
    int headerRows = 1,
    bool reverseOrder = true,
  }) async {
    final encoded = Uri.encodeComponent('$sheetTab!$range');
    final uri = Uri.parse(
      '$_base/${AppConfig.spreadsheetId}/values/$encoded?key=${AppConfig.sheetsApiKey}',
    );

    final res = await http.get(uri, headers: {'Accept': 'application/json'});

    if (res.statusCode == 200) {
      final body = json.decode(res.body) as Map<String, dynamic>;
      final values = body['values'] as List<dynamic>? ?? [];

      if (values.length <= headerRows) return [];

      final parsed = values
          .skip(headerRows)
          .where((row) => (row as List).isNotEmpty)
          .map((row) =>
              parser((row as List).map((e) => (e ?? '').toString()).toList()))
          .toList();

      return reverseOrder ? parsed.reversed.toList() : parsed;
    } else if (res.statusCode == 400 || res.statusCode == 404) {
      throw SheetNotReadyException(sheetTab);
    } else {
      final err = _parseError(res.body);
      throw Exception('Sheets API error: $err');
    }
  }

  static String _parseError(String body) {
    try {
      final m = json.decode(body) as Map<String, dynamic>;
      return (m['error'] as Map?)?['message']?.toString() ?? 'Unknown error';
    } catch (_) {
      return body.substring(0, body.length.clamp(0, 200));
    }
  }

  // ─── Sheet 1 — Leads / Inquiries ──────────────────────────────────────────
  /// Reads all inquiry leads from Sheet1. Returns newest first.
  static Future<List<Lead>> fetchLeads() => _readSheet<Lead>(
        sheetTab:    AppConfig.sheet1Leads,
        range:       AppConfig.sheet1Range,
        parser:      Lead.fromSheetRow,
        reverseOrder: true,
      );

  // ─── Sheet 2 — Property Listings ──────────────────────────────────────────
  /// Reads all property listings from Sheet2.
  /// Returned in sheet order (top = highest priority listing).
  static Future<List<Property>> fetchProperties() => _readSheet<Property>(
        sheetTab:    AppConfig.sheet2Properties,
        range:       AppConfig.sheet2Range,
        parser:      Property.fromSheetRow,
        reverseOrder: false, // keep original order — admin controls sort in sheet
      );

  // ─── Sheet 3 — Calling Records ────────────────────────────────────────────
  /// Tab name: "calling". n8n writes one row per call attempt.
  /// Throws [SheetNotReadyException] if tab not yet configured.
  static Future<List<CallingRecord>> fetchCallingRecords() =>
      _readSheet<CallingRecord>(
        sheetTab: AppConfig.sheet3Calling,
        range:    AppConfig.sheet3Range,
        parser:   CallingRecord.fromSheetRow,
        reverseOrder: true,
      );

  // ─── Sheet 4 — Appointments ───────────────────────────────────────────────
  /// Tab name: "Appointments". n8n writes one row per confirmed meeting.
  /// Throws [SheetNotReadyException] if tab not yet configured.
  static Future<List<Appointment>> fetchAppointments() =>
      _readSheet<Appointment>(
        sheetTab: AppConfig.sheet4Appointments,
        range:    AppConfig.sheet4Range,
        parser:   Appointment.fromSheetRow,
        reverseOrder: true,
      );
}

/// Thrown when the requested sheet tab does not exist or contains no data.
class SheetNotReadyException implements Exception {
  final String sheetName;
  const SheetNotReadyException(this.sheetName);

  @override
  String toString() => 'Sheet "$sheetName" is not set up or has no data.';
}
