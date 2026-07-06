/// Sheet 3 — One row per confirmed appointment.
/// n8n writes to this sheet after the AI bot agrees a meeting with the lead.
///
/// Expected columns (create these headers in Sheet3):
///   A: Timestamp        — when appointment was booked
///   B: Full Name        — lead's name
///   C: Phone            — lead's phone
///   D: Appointment Date — e.g. "15 Apr 2026"
///   E: Appointment Time — e.g. "3:00 PM"
///   F: Location         — city / area for meeting
///   G: Property Type    — Flat / House / Plot / Shop
///   H: Budget           — price range
///   I: Status           — "Confirmed" | "Cancelled" | "Completed"
///   J: Notes            — any extra notes from the call
class Appointment {
  final String timestamp;
  final String fullName;
  final String phone;
  final String appointmentDate;
  final String appointmentTime;
  final String location;
  final String propertyType;
  final String budget;
  final String status;
  final String notes;

  const Appointment({
    required this.timestamp,
    required this.fullName,
    required this.phone,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.location,
    required this.propertyType,
    required this.budget,
    required this.status,
    required this.notes,
  });

  factory Appointment.fromSheetRow(List<String> row) => Appointment(
        timestamp:       _s(row, 0),
        fullName:        _s(row, 1),
        phone:           _s(row, 2),
        appointmentDate: _s(row, 3),
        appointmentTime: _s(row, 4),
        location:        _s(row, 5),
        propertyType:    _s(row, 6),
        budget:          _s(row, 7),
        status:          _s(row, 8, fallback: 'Confirmed'),
        notes:           _s(row, 9),
      );

  static String _s(List<String> r, int i, {String fallback = ''}) =>
      i < r.length && r[i].trim().isNotEmpty ? r[i].trim() : fallback;

  ApptStatus get apptStatus {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':  return ApptStatus.confirmed;
      case 'CANCELLED':  return ApptStatus.cancelled;
      case 'COMPLETED':  return ApptStatus.completed;
      default:           return ApptStatus.confirmed;
    }
  }

  /// "15 APR 2026 · 3:00 PM"
  String get displayDateTime {
    final d = appointmentDate.trim();
    final t = appointmentTime.trim();
    if (d.isEmpty && t.isEmpty) return '—';
    if (t.isEmpty) return d;
    return '$d  ·  $t';
  }

  String get formattedCreatedAt {
    final raw = timestamp;
    if (raw.isEmpty) return '';
    try {
      DateTime dt;
      if (raw.contains('T') || raw.contains('-')) {
        dt = DateTime.parse(raw).toLocal();
      } else {
        final parts = raw.split(' ');
        final dp = parts[0].split('/');
        final tp = parts.length > 1 ? parts[1].split(':') : ['0', '0'];
        dt = DateTime(int.parse(dp[2]), int.parse(dp[0]), int.parse(dp[1]),
            int.parse(tp[0]), int.parse(tp[1]));
      }
      final p = (int n) => n.toString().padLeft(2, '0');
      const months = ['','JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
      return '${p(dt.day)} ${months[dt.month]} ${dt.year}  ${p(dt.hour)}:${p(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }
}

enum ApptStatus { confirmed, cancelled, completed }
