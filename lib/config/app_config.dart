import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// APP CONFIG — Single source of truth for all IDs, keys, and credentials.
/// ─────────────────────────────────────────────────────────────────────────
class AppConfig {
  AppConfig._();

  // ─── Admin Login ──────────────────────────────────────────────────────────
  static const String adminEmail    = 'neoenzo126@gmail.com';
  static const String adminPassword = 'Aseel';

  // ─── Google Sheets — Spreadsheet ID ──────────────────────────────────────
  static const String spreadsheetId =
      '1EpkkJlk1DhiEDV58TvNEim3Ws3mBvAb0dNS76fkm9yI';

  /// Read-only API key for the Admin dashboard (reading sheets).
  static const String sheetsApiKey = 'AIzaSyAirc73z4ty7e79rf16egicNXfFBFygYAQ';

  // ── Sheet tab names ───────────────────────────────────────────────────────
  static const String sheet1Leads        = 'Sheet1';
  static const String sheet1Range        = 'A:G';
  static const String sheet2Properties   = 'Sheet2';
  static const String sheet2Range        = 'A:J';
  static const String sheet3Calling      = 'calling';
  static const String sheet3Range        = 'A:G';
  static const String sheet4Appointments = 'Appointments';
  static const String sheet4Range        = 'A:J';

  // ─── ⚠️  NGROK BASE URL — set at runtime via the setup dialog ────────────
  /// Runtime ngrok URL — set by calling [AppConfig.setNgrokBase] from the
  /// startup configuration screen.  Falls back to last-known value.
  static String _ngrokBase = '';

  static String get ngrokBase => _ngrokBase;

  static void setNgrokBase(String url) {
    _ngrokBase = url.trim().replaceAll(RegExp(r'/$'), '');
    debugPrint('[AppConfig] ngrokBase → $_ngrokBase');
  }

  static bool get isNgrokConfigured =>
      _ngrokBase.isNotEmpty && _ngrokBase.startsWith('https://');

  // ─── Webhook endpoints (point to local Python backend via ngrok) ──────────
  static String get webhookNewLead       => '$_ngrokBase/new-lead';
  static String get webhookTriggerCall   => '$_ngrokBase/trigger-call';
  static String get webhookBookAppointment => '$_ngrokBase/book-appointment';
  static String get webhookHealth        => '$_ngrokBase/health';
}
