/// Sheet 1 — Lead submitted via Google Form or Flutter app form.
/// Columns: A:Timestamp  B:Name  C:Phone  D:Location  E:Type  F:Budget

class Lead {
  final String timestamp;
  final String fullName;
  final String phone;
  final String location;
  final String propertyType;
  final String priceRange;

  const Lead({
    required this.timestamp,
    required this.fullName,
    required this.phone,
    required this.location,
    required this.propertyType,
    required this.priceRange,
  });

  factory Lead.fromSheetRow(List<String> row) => Lead(
        timestamp:    _s(row, 0),
        fullName:     _s(row, 1),
        phone:        _s(row, 2),
        location:     _s(row, 3),
        propertyType: _s(row, 4),
        priceRange:   _s(row, 5),
      );

  static String _s(List<String> r, int i) =>
      i < r.length ? r[i].trim() : '';

  String get formattedDate => _parseDate(timestamp);

  // Handles both ISO ("2026-04-04T13:45:00") and
  // Google Forms format ("4/4/2026 13:45:00")
  static String _parseDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      DateTime dt;
      if (raw.contains('T') || raw.contains('-')) {
        dt = DateTime.parse(raw).toLocal();
      } else {
        // Google Forms: M/D/YYYY HH:MM:SS or M/D/YYYY H:MM:SS
        final parts = raw.split(' ');
        final dateParts = parts[0].split('/');
        final timeParts = parts.length > 1 ? parts[1].split(':') : ['0', '0', '0'];
        dt = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      }
      return '${_p(dt.day)} ${_m(dt.month)} ${dt.year}  '
          '${_p(dt.hour)}:${_p(dt.minute)}';
    } catch (_) {
      return raw;
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
  static String _m(int m) => const [
        '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ][m];
}
