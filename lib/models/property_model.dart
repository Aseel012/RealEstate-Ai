/// Sheet 2 — Property Listing managed by admin.
///
/// Expected columns in Sheet2 (tab: "Sheet2"):
///   A: Property Name   B: Location   C: Property Type
///   D: Price           E: Size        F: Bedrooms
///   G: Amenities       H: Description
///   I: Image URL       J: Maps Link   (NEW — exact location Google Maps URL)
class Property {
  final String name;
  final String location;
  final String propertyType;
  final String price;
  final String size;        // e.g. "2220 sq.ft" or "120 guj"
  final String bedrooms;
  final String amenities;
  final String description;
  final String imageUrl;    // direct image link shown in card
  final String mapsLink;   // Google Maps exact location link

  const Property({
    required this.name,
    required this.location,
    required this.propertyType,
    required this.price,
    required this.size,
    required this.bedrooms,
    required this.amenities,
    required this.description,
    required this.imageUrl,
    required this.mapsLink,
  });

  factory Property.fromSheetRow(List<String> row) => Property(
        name:         _s(row, 0),
        location:     _s(row, 1),
        propertyType: _s(row, 2),
        price:        _s(row, 3),
        size:         _s(row, 4),
        bedrooms:     _s(row, 5),
        amenities:    _s(row, 6),
        description:  _s(row, 7),
        imageUrl:     _s(row, 8),  // column I
        mapsLink:     _s(row, 9),  // column J
      );

  static String _s(List<String> r, int i) =>
      i < r.length ? r[i].trim() : '';

  /// Returns true if imageUrl is a valid http/https link.
  bool get hasImage => imageUrl.startsWith('http');

  /// Returns true if mapsLink is a valid http/https link.
  bool get hasMapsLink => mapsLink.startsWith('http');

  /// Size label — shows as-is (admin writes "2220 sq.ft" or "120 guj").
  String get sizeLabel => size.isEmpty ? '-' : size;

  /// Splits comma-separated amenities into a clean list.
  List<String> get amenityList => amenities
      .split(',')
      .map((a) => a.trim())
      .where((a) => a.isNotEmpty)
      .toList();

  /// How many bedrooms as an integer (0 = studio/plot).
  int get bedroomsInt {
    final cleaned = bedrooms.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.isEmpty ? 0 : int.tryParse(cleaned) ?? 0;
  }

  /// Whether this property matches a type filter (case-insensitive prefix).
  bool matchesType(String filter) {
    if (filter == 'ALL') return true;
    return propertyType.toUpperCase().startsWith(filter.toUpperCase());
  }
}
