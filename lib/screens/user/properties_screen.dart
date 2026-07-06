import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/property_model.dart';
import '../../services/sheets_reader.dart';
import '../user/lead_form_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Properties Screen — Browse Sheet2 property listings
// Columns: Name|Location|Type|Price|Size|Bedrooms|Amenities|Desc|ImageURL|MapsLink
// ─────────────────────────────────────────────────────────────────────────────
class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  List<Property> _all = [];
  List<Property> _filtered = [];
  bool _loading = true;
  String? _error;

  String _activeType = 'ALL';
  String _activeLocation = 'ALL';

  static const _typeFilters = ['ALL', 'FLAT', 'HOUSE', 'PLOT', 'VILLA', 'SHOP'];

  List<String> get _locations {
    final locs = _all.map((p) => p.location).toSet().toList()..sort();
    return ['ALL', ...locs];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await SheetsReader.fetchProperties();
      setState(() {
        _all = data;
        _loading = false;
        _applyFilters();
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((p) {
        final typeOk = _activeType == 'ALL' ||
            p.propertyType.toUpperCase().contains(_activeType);
        final locOk  = _activeLocation == 'ALL' ||
            p.location.toLowerCase() == _activeLocation.toLowerCase();
        return typeOk && locOk;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _PropertiesHeader(
              count: _filtered.length,
              totalCount: _all.length,
              loading: _loading,
            ),
            Container(height: 1, color: AppColors.border),

            if (!_loading && _error == null) ...[
              // ── Type filters ─────────────────────────────────────────────
              _TypeFilterBar(
                filters: _typeFilters,
                active: _activeType,
                onSelect: (f) { _activeType = f; _applyFilters(); },
              ),
              Container(height: 1, color: AppColors.border),

              // ── Location filter ──────────────────────────────────────────
              _LocationFilterBar(
                locations: _locations,
                active: _activeLocation,
                onSelect: (l) { _activeLocation = l; _applyFilters(); },
              ),
              Container(height: 1, color: AppColors.border),
            ],

            // ── Content ─────────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.gold),
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_filtered.isEmpty) {
      return _EmptyState(
        hasFilters: _activeType != 'ALL' || _activeLocation != 'ALL',
        onClear: () {
          setState(() { _activeType = 'ALL'; _activeLocation = 'ALL'; });
          _applyFilters();
        },
      );
    }
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => Container(
          height: 1,
          color: AppColors.border,
          margin: const EdgeInsets.symmetric(vertical: 16),
        ),
        itemBuilder: (_, i) => _PropertyCard(
          property: _filtered[i],
          onBookVisit: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => LeadFormScreen(
                prefilledType: _filtered[i].propertyType,
                prefilledLocation: _filtered[i].location,
              ),
              transitionDuration: const Duration(milliseconds: 350),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _PropertiesHeader extends StatelessWidget {
  final int count, totalCount;
  final bool loading;
  const _PropertiesHeader(
      {required this.count, required this.totalCount, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back,
                color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 16),
          Text('PROPERTY LISTINGS', style: AppText.heading),
          const Spacer(),
          if (!loading)
            Text(
              '$count LISTED',
              style: AppText.mono(
                  size: 10, color: AppColors.gold, letterSpacing: 1.5),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type Filter Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TypeFilterBar extends StatelessWidget {
  final List<String> filters;
  final String active;
  final ValueChanged<String> onSelect;

  const _TypeFilterBar(
      {required this.filters, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = filters[i];
          final isActive = f == active;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.gold.withOpacity(0.12) : Colors.transparent,
                border: Border.all(
                  color: isActive ? AppColors.gold : AppColors.border,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                f,
                style: AppText.mono(
                  size: 10,
                  color: isActive ? AppColors.gold : AppColors.textSecondary,
                  letterSpacing: 1.5,
                  weight: isActive ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Filter Bar
// ─────────────────────────────────────────────────────────────────────────────
class _LocationFilterBar extends StatelessWidget {
  final List<String> locations;
  final String active;
  final ValueChanged<String> onSelect;

  const _LocationFilterBar(
      {required this.locations, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: locations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final loc = locations[i];
          final isActive = loc == active;
          return GestureDetector(
            onTap: () => onSelect(loc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.surfaceElevated
                    : Colors.transparent,
                border: Border.all(
                  color: isActive ? AppColors.borderMid : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loc != 'ALL') ...[
                    Icon(Icons.location_on_outlined,
                        size: 10,
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    loc,
                    style: AppText.mono(
                      size: 10,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Property Card — now shows Image + Maps Link
// ─────────────────────────────────────────────────────────────────────────────
class _PropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onBookVisit;

  const _PropertyCard({required this.property, required this.onBookVisit});

  Future<void> _openMaps() async {
    final url = Uri.parse(property.mapsLink);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Property Image ──────────────────────────────────────────────────
      if (property.hasImage) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.network(
            property.imageUrl,
            key: ValueKey(property.imageUrl),
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            headers: const {'Accept': 'image/*'},
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: double.infinity,
                height: 180,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        color: AppColors.gold,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (_, error, __) {
              debugPrint('[Image] Failed: ${property.imageUrl} — $error');
              return Container(
                width: double.infinity,
                height: 80,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textMuted, size: 20),
                    const SizedBox(height: 4),
                    Text('Image unavailable',
                        style: AppText.caption.copyWith(fontSize: 9)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],

      // ── Name + Type badge ──────────────────────────────────────────────
      Row(children: [
        Expanded(
          child: Text(
            property.name.toUpperCase(),
            style: AppText.mono(size: 14, weight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(width: 10),
        _TypeBadge(property.propertyType),
      ]),
      const SizedBox(height: 6),

      // ── Location + optional Maps button ───────────────────────────────
      Row(children: [
        const Icon(Icons.location_on_outlined,
            size: 11, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(property.location, style: AppText.bodySmall),
        ),
        if (property.hasMapsLink)
          GestureDetector(
            onTap: _openMaps,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined,
                      size: 10, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(
                    'VIEW ON MAP',
                    style: AppText.mono(
                        size: 9, color: AppColors.gold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
      ]),
      const SizedBox(height: 14),

      // ── Price + Size metrics row ───────────────────────────────────────
      Row(children: [
        Text(
          property.price,
          style: AppText.mono(
            size: 18,
            color: AppColors.gold,
            weight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        // Size chip — shows "2220 sq.ft" or "120 guj" from sheet
        _MetricChip(Icons.straighten_outlined, property.sizeLabel),
        if (property.bedroomsInt > 0) ...[
          const SizedBox(width: 12),
          _MetricChip(Icons.bed_outlined, '${property.bedroomsInt} BHK'),
        ],
      ]),
      const SizedBox(height: 12),

      // ── Amenity chips ─────────────────────────────────────────────────
      if (property.amenityList.isNotEmpty) ...[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: property.amenityList
              .take(4)
              .map((a) => _AmenityChip(a))
              .toList(),
        ),
        const SizedBox(height: 12),
      ],

      // ── Description ───────────────────────────────────────────────────
      if (property.description.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border:
                Border(left: BorderSide(color: AppColors.goldDim, width: 2)),
          ),
          child: Text(
            property.description,
            style: AppText.bodySmall.copyWith(height: 1.6),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 14),
      ],

      // ── Book Visit CTA ────────────────────────────────────────────────
      GestureDetector(
        onTap: onBookVisit,
        child: Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 12, color: AppColors.gold),
              const SizedBox(width: 8),
              Text(
                'BOOK SITE VISIT',
                style: AppText.mono(
                  size: 11,
                  color: AppColors.gold,
                  weight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ━━━ Atoms ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge(this.type);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.08),
          border: Border.all(color: AppColors.goldDim),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          type.toUpperCase(),
          style: AppText.mono(
              size: 9, color: AppColors.gold, letterSpacing: 1.5),
        ),
      );
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetricChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppText.bodySmall),
        ],
      );
}

class _AmenityChip extends StatelessWidget {
  final String label;
  const _AmenityChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: AppText.mono(
              size: 9, color: AppColors.textSecondary, letterSpacing: 0.5),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// States
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.textMuted, size: 28),
              const SizedBox(height: 16),
              Text('COULD NOT LOAD',
                  style: AppText.mono(
                      size: 12,
                      color: AppColors.textSecondary,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(message,
                  style: AppText.caption, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onRetry,
                child: Text('RETRY →',
                    style: AppText.mono(
                        size: 11, color: AppColors.gold, letterSpacing: 2)),
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyState({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NO PROPERTIES FOUND',
                style: AppText.mono(
                    size: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 2)),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onClear,
                child: Text('CLEAR FILTERS →',
                    style: AppText.mono(
                        size: 11, color: AppColors.gold, letterSpacing: 2)),
              ),
            ],
          ],
        ),
      );
}
