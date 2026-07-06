import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/lead_model.dart';
import '../../models/calling_record.dart';
import '../../models/appointment.dart';
import '../../services/sheets_reader.dart';
import '../../screens/splash_screen.dart';
import '../../screens/ngrok_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Dashboard — 3 tabs (Leads · Calling · Appointments)
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Tab 1: Leads ─────────────────────────────────────────────────
  List<Lead> _leads = [];
  bool      _leadsLoading  = true;
  String?   _leadsError;

  // ── Tab 2: Calling ───────────────────────────────────────────────
  List<CallingRecord> _calls         = [];
  bool                _callsLoading  = false;
  bool                _callsLoaded   = false;
  bool                _callsMissing  = false;
  String?             _callsError;

  // ── Tab 3: Appointments ──────────────────────────────────────────
  List<Appointment> _appts        = [];
  bool              _apptsLoading = false;
  bool              _apptsLoaded  = false;
  bool              _apptsMissing = false;
  String?           _apptsError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabSwitch);
    _loadLeads();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabSwitch)
      ..dispose();
    super.dispose();
  }

  // ── Lazy-load on tab switch ──────────────────────────────────────
  void _onTabSwitch() {
    if (_tabs.indexIsChanging) return; // wait for animation
    switch (_tabs.index) {
      case 1: if (!_callsLoaded) _loadCalls(); break;
      case 2: if (!_apptsLoaded) _loadAppointments(); break;
    }
  }

  // ── Loaders ──────────────────────────────────────────────────────
  Future<void> _loadLeads() async {
    setState(() { _leadsLoading = true; _leadsError = null; });
    try {
      final data = await SheetsReader.fetchLeads();
      setState(() { _leads = data; _leadsLoading = false; });
    } catch (e) {
      setState(() { _leadsError = e.toString(); _leadsLoading = false; });
    }
  }

  Future<void> _loadCalls() async {
    setState(() { _callsLoading = true; _callsError = null; _callsMissing = false; });
    try {
      final data = await SheetsReader.fetchCallingRecords();
      setState(() {
        _calls = data; _callsLoading = false; _callsLoaded = true;
      });
    } on SheetNotReadyException {
      setState(() { _callsMissing = true; _callsLoading = false; _callsLoaded = true; });
    } catch (e) {
      setState(() { _callsError = e.toString(); _callsLoading = false; _callsLoaded = true; });
    }
  }

  Future<void> _loadAppointments() async {
    setState(() { _apptsLoading = true; _apptsError = null; _apptsMissing = false; });
    try {
      final data = await SheetsReader.fetchAppointments();
      setState(() {
        _appts = data; _apptsLoading = false; _apptsLoaded = true;
      });
    } on SheetNotReadyException {
      setState(() { _apptsMissing = true; _apptsLoading = false; _apptsLoaded = true; });
    } catch (e) {
      setState(() { _apptsError = e.toString(); _apptsLoading = false; _apptsLoaded = true; });
    }
  }

  // ── Refresh current tab ──────────────────────────────────────────
  Future<void> _refresh() async {
    switch (_tabs.index) {
      case 0: await _loadLeads(); break;
      case 1: _callsLoaded = false; await _loadCalls(); break;
      case 2: _apptsLoaded = false; await _loadAppointments(); break;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──────────────────────────────────────────
            _AppBar(onRefresh: _refresh, onLogout: _logout),
            Container(height: 1, color: AppColors.border),

            // ── KPI Strip ────────────────────────────────────────
            _KpiStrip(
              leads:       _leads.length,
              calls:       _callsMissing ? -1 : _calls.length,
              meetings:    _apptsMissing ? -1 : _appts.length,
              activeTab:   _tabs.index,
              onTapLeads:  () => _tabs.animateTo(0),
              onTapCalls:  () { _tabs.animateTo(1); if (!_callsLoaded) _loadCalls(); },
              onTapMeets:  () { _tabs.animateTo(2); if (!_apptsLoaded) _loadAppointments(); },
            ),
            Container(height: 1, color: AppColors.border),

            // ── Custom Tab Bar ────────────────────────────────────
            _RetroTabBar(controller: _tabs,
              labels: ['INQUIRIES', 'CALLING', 'MEETINGS'],
              counts: [
                _leads.length,
                _callsMissing ? -1 : _calls.length,
                _apptsMissing ? -1 : _appts.length,
              ],
            ),
            Container(height: 1, color: AppColors.border),

            // ── Tab Content ──────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // Tab 1 — Leads
                  _LeadsTab(
                    leads:   _leads,
                    loading: _leadsLoading,
                    error:   _leadsError,
                    onRetry: _loadLeads,
                    onRefresh: _loadLeads,
                  ),
                  // Tab 2 — Calling
                  _CallingTab(
                    records:   _calls,
                    loading:   _callsLoading,
                    missing:   _callsMissing,
                    error:     _callsError,
                    onRetry:   () { _callsLoaded = false; _loadCalls(); },
                    onRefresh: () { _callsLoaded = false; return _loadCalls(); },
                  ),
                  // Tab 3 — Appointments
                  _AppointmentsTab(
                    appts:     _appts,
                    loading:   _apptsLoading,
                    missing:   _apptsMissing,
                    error:     _apptsError,
                    onRetry:   () { _apptsLoaded = false; _loadAppointments(); },
                    onRefresh: () { _apptsLoaded = false; return _loadAppointments(); },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
      (route) => false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  const _AppBar({required this.onRefresh, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text('DASHBOARD', style: AppText.heading),
          const Spacer(),
          // Backend URL reconfigure
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    NgrokSetupScreen(isFirstRun: false),
                transitionDuration: Duration(milliseconds: 350),
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
              ),
            ),
            child: const Icon(Icons.wifi_outlined,
                color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 18),
          GestureDetector(
            onTap: onLogout,
            child: const Icon(Icons.power_settings_new,
                color: AppColors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Strip
// ─────────────────────────────────────────────────────────────────────────────
class _KpiStrip extends StatelessWidget {
  final int leads, calls, meetings, activeTab;
  final VoidCallback onTapLeads, onTapCalls, onTapMeets;

  const _KpiStrip({
    required this.leads,   required this.calls,    required this.meetings,
    required this.activeTab,
    required this.onTapLeads, required this.onTapCalls, required this.onTapMeets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _KpiCell(
            value: leads.toString(),
            label: 'INQUIRIES',
            active: activeTab == 0,
            onTap: onTapLeads,
          ),
          _KpiDivider(),
          _KpiCell(
            value: calls < 0 ? '—' : calls.toString(),
            label: 'CALLS MADE',
            active: activeTab == 1,
            onTap: onTapCalls,
          ),
          _KpiDivider(),
          _KpiCell(
            value: meetings < 0 ? '—' : meetings.toString(),
            label: 'MEETINGS',
            active: activeTab == 2,
            highlight: meetings > 0,
            onTap: onTapMeets,
          ),
        ],
      ),
    );
  }
}

class _KpiDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppColors.border);
}

class _KpiCell extends StatelessWidget {
  final String value, label;
  final bool active, highlight;
  final VoidCallback onTap;

  const _KpiCell({
    required this.value,
    required this.label,
    required this.active,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Text(
            value,
            style: AppText.mono(
              size: 26,
              color: active
                  ? AppColors.gold
                  : highlight
                      ? AppColors.statusAppointedText
                      : AppColors.textPrimary,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.label.copyWith(
              color: active ? AppColors.gold : AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Retro Tab Bar
// ─────────────────────────────────────────────────────────────────────────────
class _RetroTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final List<int> counts;

  const _RetroTabBar({
    required this.controller,
    required this.labels,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: List.generate(labels.length, (i) {
          final active = controller.index == i;
          final count  = counts[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.gold.withOpacity(0.07)
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: active ? AppColors.gold : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  count < 0
                      ? labels[i]
                      : '${labels[i]}  $count',
                  style: AppText.mono(
                    size: 10,
                    color: active ? AppColors.gold : AppColors.textSecondary,
                    letterSpacing: 1.5,
                    weight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — Leads (Sheet1)
// ═════════════════════════════════════════════════════════════════════════════
class _LeadsTab extends StatelessWidget {
  final List<Lead> leads;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _LeadsTab({
    required this.leads,   required this.loading,
    required this.error,   required this.onRetry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loader();
    if (error != null) return _ErrorView(msg: error!, onRetry: onRetry);
    if (leads.isEmpty) return const _EmptyView(label: 'NO INQUIRIES YET');

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: leads.length,
        separatorBuilder: (_, __) => Container(
          height: 1, color: AppColors.border,
          margin: const EdgeInsets.symmetric(vertical: 14),
        ),
        itemBuilder: (_, i) => _LeadCard(lead: leads[i]),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Name
      Text(
        lead.fullName.toUpperCase(),
        style: AppText.mono(size: 14, weight: FontWeight.w500, letterSpacing: 0.5),
      ),
      const SizedBox(height: 8),
      // Phone · Location
      Row(children: [
        const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(lead.phone, style: AppText.bodySmall),
        const SizedBox(width: 16),
        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(lead.location, style: AppText.bodySmall),
      ]),
      const SizedBox(height: 8),
      // Tags
      Row(children: [
        _Tag(lead.propertyType),
        const SizedBox(width: 8),
        _Tag(lead.priceRange, gold: true),
      ]),
      const SizedBox(height: 10),
      Text(lead.formattedDate, style: AppText.caption),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — Calling Records (Sheet2)
// ═════════════════════════════════════════════════════════════════════════════
class _CallingTab extends StatelessWidget {
  final List<CallingRecord> records;
  final bool loading, missing;
  final String? error;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _CallingTab({
    required this.records,  required this.loading,
    required this.missing,  required this.error,
    required this.onRetry,  required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loader();
    if (missing) return _SetupCard(
      sheetName: 'Sheet2',
      description:
          'n8n writes one row here per call attempt.\nOnce the calling workflow is live, call logs appear here.',
      columns: const [
        'A  Timestamp', 'B  Full Name', 'C  Phone',
        'D  Call Status  (Reached / Not Reached / Voicemail)',
        'E  Duration', 'F  Bot Summary', 'G  Next Action',
      ],
    );
    if (error != null) return _ErrorView(msg: error!, onRetry: onRetry);
    if (records.isEmpty) return const _EmptyView(label: 'NO CALLS YET');

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: records.length,
        separatorBuilder: (_, __) => Container(
          height: 1, color: AppColors.border,
          margin: const EdgeInsets.symmetric(vertical: 14),
        ),
        itemBuilder: (_, i) => _CallingCard(record: records[i]),
      ),
    );
  }
}

class _CallingCard extends StatelessWidget {
  final CallingRecord record;
  const _CallingCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _statusStyle(record.status);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            record.fullName.toUpperCase(),
            style: AppText.mono(size: 14, weight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ),
        _StatusBadge(label: label, bg: bg, fg: fg),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(record.phone, style: AppText.bodySmall),
        if (record.duration.isNotEmpty) ...[
          const SizedBox(width: 16),
          const Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(record.duration, style: AppText.bodySmall),
        ],
      ]),
      if (record.summary.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            border: Border(left: BorderSide(color: AppColors.border, width: 2)),
          ),
          child: Text('"${record.summary}"',
              style: AppText.bodySmall.copyWith(fontStyle: FontStyle.italic)),
        ),
      ],
      if (record.nextAction.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.arrow_forward, size: 12, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(record.nextAction,
              style: AppText.mono(size: 11, color: AppColors.gold)),
        ]),
      ],
      const SizedBox(height: 8),
      Text(record.formattedDate, style: AppText.caption),
    ]);
  }

  (String, Color, Color) _statusStyle(CallStatus s) {
    switch (s) {
      case CallStatus.reached:
        return ('REACHED', AppColors.statusAppointed.withOpacity(0.3),
            AppColors.statusAppointedText);
      case CallStatus.voicemail:
        return ('VOICEMAIL', AppColors.statusCalled.withOpacity(0.3),
            AppColors.statusCalledText);
      case CallStatus.notReached:
        return ('NOT REACHED', AppColors.statusPending.withOpacity(0.3),
            AppColors.statusPendingText);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — Appointments (Sheet3)
// ═════════════════════════════════════════════════════════════════════════════
class _AppointmentsTab extends StatelessWidget {
  final List<Appointment> appts;
  final bool loading, missing;
  final String? error;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _AppointmentsTab({
    required this.appts,    required this.loading,
    required this.missing,  required this.error,
    required this.onRetry,  required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loader();
    if (missing) return _SetupCard(
      sheetName: 'Sheet3',
      description:
          'n8n writes one row here when the AI bot confirms a physical meeting.\nAppointment date, time, and status appear once active.',
      columns: const [
        'A  Timestamp (booked at)',
        'B  Full Name', 'C  Phone',
        'D  Appointment Date', 'E  Appointment Time',
        'F  Location', 'G  Property Type', 'H  Budget',
        'I  Status  (Confirmed / Cancelled / Completed)',
        'J  Notes',
      ],
    );
    if (error != null) return _ErrorView(msg: error!, onRetry: onRetry);
    if (appts.isEmpty) return const _EmptyView(label: 'NO MEETINGS BOOKED');

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: appts.length,
        separatorBuilder: (_, __) => Container(
          height: 1, color: AppColors.border,
          margin: const EdgeInsets.symmetric(vertical: 14),
        ),
        itemBuilder: (_, i) => _AppointmentCard(appt: appts[i]),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appt;
  const _AppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _statusStyle(appt.apptStatus);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            appt.fullName.toUpperCase(),
            style: AppText.mono(size: 14, weight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ),
        _StatusBadge(label: label, bg: bg, fg: fg),
      ]),
      const SizedBox(height: 10),

      // Appointment date/time block
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fg.withOpacity(0.07),
          border: Border.all(color: fg.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: fg),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'APPOINTMENT',
              style: AppText.label.copyWith(color: fg, letterSpacing: 2),
            ),
            const SizedBox(height: 3),
            Text(
              appt.displayDateTime,
              style: AppText.mono(size: 13, color: fg, weight: FontWeight.w500),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 10),

      // Location · Type · Budget
      Row(children: [
        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(appt.location, style: AppText.bodySmall),
        const SizedBox(width: 12),
        _Tag(appt.propertyType),
        const SizedBox(width: 8),
        _Tag(appt.budget, gold: true),
      ]),

      // Notes
      if (appt.notes.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('"${appt.notes}"',
            style: AppText.bodySmall.copyWith(fontStyle: FontStyle.italic)),
      ],
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.phone_outlined, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(appt.phone, style: AppText.bodySmall),
        const Spacer(),
        Text(appt.formattedCreatedAt, style: AppText.caption),
      ]),
    ]);
  }

  (String, Color, Color) _statusStyle(ApptStatus s) {
    switch (s) {
      case ApptStatus.confirmed:
        return ('CONFIRMED', AppColors.statusAppointed.withOpacity(0.3),
            AppColors.statusAppointedText);
      case ApptStatus.completed:
        return ('COMPLETED', AppColors.gold.withOpacity(0.15), AppColors.gold);
      case ApptStatus.cancelled:
        return ('CANCELLED', AppColors.error.withOpacity(0.3), AppColors.errorText);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Setup Card — shown when a sheet tab doesn't exist yet
// ─────────────────────────────────────────────────────────────────────────────
class _SetupCard extends StatelessWidget {
  final String sheetName, description;
  final List<String> columns;

  const _SetupCard({
    required this.sheetName,
    required this.description,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(sheetName,
                style: AppText.mono(size: 10, color: AppColors.gold, letterSpacing: 1.5)),
          ),
          const SizedBox(width: 12),
          Text('NOT CONFIGURED',
              style: AppText.label.copyWith(color: AppColors.textSecondary, letterSpacing: 2)),
        ]),
        const SizedBox(height: 20),
        Text(description,
            style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.7)),
        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),
        Text('EXPECTED COLUMNS',
            style: AppText.label.copyWith(color: AppColors.textMuted, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...columns.map(
          (col) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 4, height: 4, color: AppColors.border),
              const SizedBox(width: 10),
              Text(col, style: AppText.bodySmall),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),
        Text(
          'Set up your n8n workflow to write to $sheetName.\n'
          'Once the sheet exists and has data, this tab will load automatically on refresh.',
          style: AppText.caption.copyWith(color: AppColors.textMuted, height: 1.7),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI atoms
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _StatusBadge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2)),
        child: Text(
          '◉  $label',
          style: AppText.mono(size: 9, color: fg, letterSpacing: 1.5, weight: FontWeight.w500),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final bool gold;
  const _Tag(this.label, {this.gold = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: gold ? AppColors.goldDim.withOpacity(0.2) : AppColors.surfaceElevated,
          border: Border.all(color: gold ? AppColors.goldDim : AppColors.border),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: AppText.mono(
              size: 10, color: gold ? AppColors.gold : AppColors.textSecondary),
        ),
      );
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ERROR', style: AppText.label.copyWith(color: AppColors.errorText, letterSpacing: 3)),
          const SizedBox(height: 12),
          Text(msg, style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Text('↺  RETRY',
                style: AppText.mono(size: 12, color: AppColors.gold, letterSpacing: 2)),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String label;
  const _EmptyView({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.inbox_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(label, style: AppText.label.copyWith(letterSpacing: 3, color: AppColors.textMuted)),
        ]),
      );
}
