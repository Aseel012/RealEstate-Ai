/// Sheet 2 — One row per call attempt made by the AI bot.
/// n8n writes to this sheet after each call.
///
/// Expected columns in Sheet2:
///   A: Timestamp    — when the call was made (ISO or Google format)
///   B: Full Name    — lead's name
///   C: Phone        — lead's phone
///   D: Call Status  — "Reached" | "Not Reached" | "Voicemail"
///   E: Duration     — call length (e.g. "2m 35s")
///   F: Bot Summary  — AI-generated call summary
///   G: Next Action  — e.g. "Schedule Meeting" | "Call Again"
class CallingRecord {
  final String timestamp;
  final String fullName;
  final String phone;
  final String callStatus;
  final String duration;
  final String summary;
  final String nextAction;

  const CallingRecord({
    required this.timestamp,
    required this.fullName,
    required this.phone,
    required this.callStatus,
    required this.duration,
    required this.summary,
    required this.nextAction,
  });

  factory CallingRecord.fromSheetRow(List<String> row) => CallingRecord(
        timestamp:  _s(row, 0),
        fullName:   _s(row, 1),
        phone:      _s(row, 2),
        callStatus: _s(row, 3, fallback: 'UNKNOWN'),
        duration:   _s(row, 4),
        summary:    _s(row, 5),
        nextAction: _s(row, 6),
      );

  static String _s(List<String> r, int i, {String fallback = ''}) =>
      i < r.length && r[i].trim().isNotEmpty ? r[i].trim() : fallback;

  CallStatus get status {
    switch (callStatus.toUpperCase()) {
      case 'REACHED':
        return CallStatus.reached;
      case 'VOICEMAIL':
        return CallStatus.voicemail;
      case 'NOT REACHED':
      case 'NO ANSWER':
        return CallStatus.notReached;
      default:
        return CallStatus.notReached;
    }
  }

  /// Formats the timestamp to "04 APR 2026  13:45"
  String get formattedDate => _parseDate(timestamp);

  static String _parseDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      DateTime dt;
      if (raw.contains('T') || (raw.contains('-') && raw.contains(':'))) {
        dt = DateTime.parse(raw).toLocal();
      } else {
        // Google Forms format: M/D/YYYY HH:MM:SS
        final parts = raw.split(' ');
        final dp = parts[0].split('/');
        final tp = parts.length > 1 ? parts[1].split(':') : ['0', '0'];
        dt = DateTime(
          int.parse(dp[2]), int.parse(dp[0]), int.parse(dp[1]),
          int.parse(tp[0]), int.parse(tp[1]),
        );
      }
      final p = (int n) => n.toString().padLeft(2, '0');
      const months = [
        '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
      ];
      return '${p(dt.day)} ${months[dt.month]} ${dt.year}  ${p(dt.hour)}:${p(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }
}

enum CallStatus { reached, notReached, voicemail }
