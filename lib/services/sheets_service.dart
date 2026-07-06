/// SheetsService — legacy stub (kept for compilation compatibility).
///
/// All writes to Google Sheets are handled by the Python backend (server.py)
/// via [WebhookService].  This class is intentionally a no-op.
class SheetsService {
  SheetsService._();
  static final SheetsService instance = SheetsService._();
}
