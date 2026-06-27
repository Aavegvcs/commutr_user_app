import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/model/trip_schedule_flow_args.dart';
import 'package:commutr_main/features/trip_detail/presentation/screen/select_office.dart';
import 'package:commutr_main/weekly_off/bloc/weekly_off_bloc.dart';
import 'package:commutr_main/weekly_off/bloc/weekly_off_event.dart';
import 'package:commutr_main/weekly_off/bloc/weekly_off_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TripDetailsScreen extends StatelessWidget {
  /// When set (edit from welcome), dates and trip type are pre-filled.
  final TripScheduleFlowArgs? flowArgs;

  /// Per-location AppControl flag. When `true`, a "Select random dates" switch
  /// is shown; turning it on lets the user pick multiple non-contiguous dates
  /// (instead of a range) which are scheduled via `/TransRoster/UpdateScheduleHybrid`.
  final bool hybridScheduleEnabled;

  const TripDetailsScreen({
    super.key,
    this.flowArgs,
    this.hybridScheduleEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WeeklyOffBloc>()..add(LoadWeeklyOffEvent()),
      child: _TripDetailsView(
        flowArgs: flowArgs,
        hybridScheduleEnabled: hybridScheduleEnabled,
      ),
    );
  }
}

class _TripDetailsView extends StatefulWidget {
  final TripScheduleFlowArgs? flowArgs;
  final bool hybridScheduleEnabled;

  const _TripDetailsView({
    this.flowArgs,
    required this.hybridScheduleEnabled,
  });

  @override
  State<_TripDetailsView> createState() => _TripDetailsViewState();
}

class _TripDetailsViewState extends State<_TripDetailsView> {
  bool isLogIn = true;

  /// One-day selection (same start/end in the range picker).
  /// Defaults to today so the current date is pre-selected on first load.
  DateTime? _selectedSingleDate = _dateOnly(DateTime.now());

  bool get _isEditFlow => widget.flowArgs?.isEdit == true;

  @override
  void initState() {
    super.initState();
    _applyFlowArgs(widget.flowArgs);
  }

  void _applyFlowArgs(TripScheduleFlowArgs? args) {
    if (args == null) return;
    isLogIn = args.isLogIn;
    if (!args.hasValidDates) return;
    final start = parseIsoDate(args.fromDate);
    final end = parseIsoDate(args.toDate);
    if (start == null || end == null) return;
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    if (s == e) {
      _selectedSingleDate = s;
      _selectedRanges = [];
    } else {
      _selectedSingleDate = null;
      _selectedRanges = [DateTimeRange(start: s, end: e)];
    }
  }

  /// Completed ranges (inclusive start/end, date-only).
  List<DateTimeRange> _selectedRanges = [];

  /// When `true` (hybrid only), the user picks multiple individual dates rather
  /// than a contiguous range. Backed by [_selectedHybridDates].
  bool _randomDateSelect = false;

  /// Individual dates chosen in random-date mode (date-only).
  final Set<DateTime> _selectedHybridDates = {};

  // 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  // Sourced exclusively from the weekly-off API; `null` until loaded (or when
  // the API returns no value). No static fallback — Next is blocked (with a
  // snackbar) while this is null/empty.
  Set<int>? weeklyOffs;

  /// `true` once the weekly-off API has responded with a usable, non-empty set.
  bool get _hasWeeklyOffs => weeklyOffs != null && weeklyOffs!.isNotEmpty;

  final Color primaryGreen = const Color(0xFF1A6B3C);
  final Color lightGreen = const Color(0xFFE8F5EE);
  final Color borderGreen = const Color(0xFFB8DEC9);

  static const List<String> _dayLabels = [
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT'
  ];
  static const List<String> _dayFull = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  // Flutter's date.weekday: Mon=1 ... Sat=6, Sun=7  →  map to 0=Sun..6=Sat
  bool _isWeekOff(DateTime date) =>
      weeklyOffs?.contains(date.weekday % 7) ?? false;
  bool _isWeekOffForSet(DateTime date, Set<int> offs) =>
      offs.contains(date.weekday % 7);

  bool _rangeContainsWeekOff(DateTimeRange range, Set<int> offs) {
    var d = _dateOnly(range.start);
    final end = _dateOnly(range.end);
    while (!d.isAfter(end)) {
      if (_isWeekOffForSet(d, offs)) return true;
      d = d.add(const Duration(days: 1));
    }
    return false;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

  /// `true` when the hybrid random-date selector is active.
  bool get _isRandomMode => widget.hybridScheduleEnabled && _randomDateSelect;

  int _totalSelectedDayCount() {
    if (_isRandomMode) return _selectedHybridDates.length;
    int n = 0;
    for (final r in _selectedRanges) {
      n += r.end.difference(r.start).inDays + 1;
    }
    if (_selectedRanges.isEmpty && _selectedSingleDate != null) {
      n = 1;
    }
    return n;
  }

  bool get _hasOnlySingleDate =>
      _selectedSingleDate != null && _selectedRanges.isEmpty;

  String _formatShortDate(DateTime? date) {
    if (date == null) return '—';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final w = _dayLabels[date.weekday % 7];
    return '${date.day} ${months[date.month - 1]}, $w';
  }

  DateTime? get _rangeStartDisplay {
    if (_selectedRanges.isNotEmpty) return _selectedRanges.last.start;
    return _selectedSingleDate;
  }

  DateTime? get _rangeEndDisplay {
    if (_selectedRanges.isNotEmpty) return _selectedRanges.last.end;
    return _selectedSingleDate;
  }

  DateTimeRange? get _initialPickerRange {
    if (_selectedRanges.isNotEmpty) {
      final r = _selectedRanges.last;
      return DateTimeRange(start: _dateOnly(r.start), end: _dateOnly(r.end));
    }
    if (_selectedSingleDate != null) {
      final d = _dateOnly(_selectedSingleDate!);
      return DateTimeRange(start: d, end: d);
    }
    return null;
  }

  void _applyDateRange(DateTimeRange picked) {
    final start = _dateOnly(picked.start);
    final end = _dateOnly(picked.end);
    setState(() {
      if (_sameDay(start, end)) {
        _selectedSingleDate = start;
        _selectedRanges = [];
      } else {
        _selectedSingleDate = null;
        _selectedRanges = [DateTimeRange(start: start, end: end)];
      }
    });
  }

  void _clearAllDateSelections() {
    setState(() {
      _selectedSingleDate = null;
      _selectedRanges = [];
      _selectedHybridDates.clear();
    });
  }

  void _toggleHybridDate(DateTime day) {
    final d = _dateOnly(day);
    setState(() {
      if (_selectedHybridDates.contains(d)) {
        _selectedHybridDates.remove(d);
      } else {
        _selectedHybridDates.add(d);
      }
    });
  }

  // ─── Bottom sheet ──────────────────────────────────────────────────────────
  void _showEditWeeklyOffsSheet() {
    Set<int> tempOffs = Set.from(weeklyOffs ?? const <int>{});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_today_outlined,
                        color: primaryGreen, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Weekly Offs',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap to toggle days on or off',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 20),

              // 7-day grid  (4 cols → row 1: Sun Mon Tue Wed | row 2: Thu Fri Sat)
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: List.generate(7, (i) {
                  final selected = tempOffs.contains(i);
                  return GestureDetector(
                    onTap: () {
                      setSheet(() {
                        if (selected && tempOffs.length > 1) {
                          tempOffs.remove(i);
                        } else if (!selected) {
                          tempOffs.add(i);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: selected ? primaryGreen : lightGreen,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected ? primaryGreen : borderGreen,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _dayLabels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : primaryGreen,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // Warning when only 1 day left
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: tempOffs.length == 1
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 6),
                            Text(
                              'At least 1 weekly off must remain',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Summary chip
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderGreen),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${tempOffs.length} day${tempOffs.length == 1 ? '' : 's'} off: ${_summaryText(tempOffs)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cancel / Apply
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primaryGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          weeklyOffs = Set.from(tempOffs);
                          _selectedRanges = _selectedRanges
                              .where((r) => !_rangeContainsWeekOff(r, tempOffs))
                              .toList();
                          if (_selectedSingleDate != null &&
                              _isWeekOffForSet(
                                  _selectedSingleDate!, tempOffs)) {
                            _selectedSingleDate = null;
                          }
                          _selectedHybridDates.removeWhere(
                              (d) => _isWeekOffForSet(d, tempOffs));
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _summaryText(Set<int> offs) {
    final sorted = offs.toList()..sort();
    return sorted.map((i) => _dayFull[i]).join(', ');
  }

  String _weekOffsApiString(Set<int> offs) {
    final sorted = offs.toList()..sort();
    return sorted.map((i) => _dayLabels[i]).join(', ');
  }

  String _formatApiDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Parses the API's weekly-off string into a day-index set, or `null` when
  /// the value is missing/empty/unparseable. No static fallback.
  Set<int>? _parseWeeklyOff(String? weekOff) {
    if (weekOff == null || weekOff.trim().isEmpty) return null;
    final parsed = weekOff
        .split(',')
        .map((s) => _dayLabels.indexOf(s.trim().toUpperCase()))
        .where((i) => i >= 0)
        .toSet();
    return parsed.isEmpty ? null : parsed;
  }

  void _handleSessionExpired(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFB40D1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MobileNoVerification()),
      (route) => false,
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocListener<WeeklyOffBloc, WeeklyOffState>(
      listener: (context, state) {
        if (state is WeeklyOffLoaded) {
          final row = state.response.result?.isNotEmpty == true
              ? state.response.result!.first
              : null;
          if (!mounted) return;
          final newWeeklyOffs = _parseWeeklyOff(row?.weekOff);
          setState(() {
            weeklyOffs = newWeeklyOffs;
            // If today (pre-selected by default) is a weekly off per the
            // loaded config, drop the pre-selection so the picker stays valid.
            if (_selectedSingleDate != null &&
                newWeeklyOffs != null &&
                _isWeekOffForSet(_selectedSingleDate!, newWeeklyOffs)) {
              _selectedSingleDate = null;
            }
          });
        } else if (state is WeeklyOffUnauthorized) {
          _handleSessionExpired(state.message);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildProgressBar(),
                      const SizedBox(height: 20),
                      _buildLoginToggle(),
                      const SizedBox(height: 16),
                      _buildWeeklyOffs(),
                      const SizedBox(height: 16),
                      _buildDateRangeSection(),
                      const SizedBox(height: 16),
                      _buildStatus(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildNextButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
              splashColor: Colors.transparent,
              onTap: () {
                Navigator.of(context).pop();
              },
              child: Icon(Icons.arrow_back, color: primaryGreen, size: 22)),
          const SizedBox(width: 8),
          Text(
            'Trip Details',
            style: TextStyle(
              color: primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(4, (index) {
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
            decoration: BoxDecoration(
              color: index == 0 ? primaryGreen : const Color(0xFFD0E8D9),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoginToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderGreen, width: 1),
      ),
      child: Row(
        children: [
          _buildToggleBtn('Log In', isLogIn, enabled: !_isEditFlow),
          _buildToggleBtn('Logout', !isLogIn, enabled: !_isEditFlow),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive, {bool enabled = true}) {
    return Expanded(
      child: GestureDetector(
        onTap:
            enabled ? () => setState(() => isLogIn = label == 'Log In') : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? primaryGreen : const Color(0xFF888888),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyOffs() {
    final sortedOffs = (weeklyOffs?.toList() ?? [])..sort();
    return BlocBuilder<WeeklyOffBloc, WeeklyOffState>(
      builder: (context, state) {
        // Show the spinner while fetching and until a usable set is available.
        final isLoading = state is WeeklyOffLoading ||
            state is WeeklyOffInitial ||
            !_hasWeeklyOffs;
        return GestureDetector(
          onTap: isLoading ? null : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_today_outlined,
                      color: primaryGreen, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weekly Offs',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryGreen,
                    ),
                  )
                else
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: sortedOffs
                          .map((i) => _buildChip(_dayLabels[i]))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0D0D0), width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF444444),
        ),
      ),
    );
  }

  Widget _buildDateRangeSection() {
    final hasSelection = _rangeStartDisplay != null || _rangeEndDisplay != null;
    final today = _dateOnly(DateTime.now());
    final lastDate = DateTime(today.year + 1, 12, 31);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.hybridScheduleEnabled) ...[
          _buildRandomDateSwitch(),
          const SizedBox(height: 12),
        ],
        if (!_isRandomMode)
          Row(
            children: [
              Expanded(
                child: _dateFieldBox(
                  label: 'FROM',
                  value: _formatShortDate(_rangeStartDisplay),
                  isPlaceholder: _rangeStartDisplay == null,
                  isActive: hasSelection,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward,
                  size: 18, color: primaryGreen.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: _dateFieldBox(
                  label: 'TO',
                  value: _formatShortDate(_rangeEndDisplay),
                  isPlaceholder: _rangeEndDisplay == null,
                  isActive: hasSelection,
                ),
              ),
            ],
          ),
        if (!_isRandomMode) const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Text(
                  _isRandomMode
                      ? 'Tap dates to select multiple'
                      : 'Select travel dates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryGreen.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 340,
                child: _HorizontalDateRangePicker(
                  key: ValueKey('$_randomDateSelect-$_initialPickerRange'),
                  multiSelect: _isRandomMode,
                  selectedDates: _selectedHybridDates,
                  onDateToggled: _toggleHybridDate,
                  initialRange: _initialPickerRange,
                  firstDate: today,
                  lastDate: lastDate,
                  primaryColor: primaryGreen,
                  lightColor: lightGreen,
                  isSelectable: (day) =>
                      !day.isBefore(today) && !_isWeekOff(day),
                  onRangeSelected: _applyDateRange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRandomDateSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _randomDateSelect ? lightGreen : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _randomDateSelect ? primaryGreen : const Color(0xFFE5E5E5),
          width: _randomDateSelect ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, color: primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select random dates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  'Pick multiple individual days instead of a range',
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryGreen.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _randomDateSelect,
            activeThumbColor: primaryGreen,
            onChanged: (v) {
              setState(() {
                _randomDateSelect = v;
                // Reset selections when switching modes so the two pickers
                // never carry stale state across each other.
                _selectedSingleDate = null;
                _selectedRanges = [];
                _selectedHybridDates.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _dateFieldBox({
    required String label,
    required String value,
    required bool isPlaceholder,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? lightGreen : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? primaryGreen : const Color(0xFFE5E5E5),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: primaryGreen.withValues(alpha: 0.7),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPlaceholder ? 'Tap to select' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPlaceholder
                  ? const Color(0xFFAAAAAA)
                  : const Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatus() {
    final count = _totalSelectedDayCount();
    final rangeCount = _selectedRanges.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primaryGreen,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (count > 0)
                TextButton(
                  onPressed: _clearAllDateSelections,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            count == 0
                ? 'Select travel dates below'
                : _isRandomMode
                    ? '$count date${count == 1 ? '' : 's'} selected'
                    : _hasOnlySingleDate
                        ? 'Travel on ${_formatShortDate(_selectedSingleDate)}'
                        : '$count day${count == 1 ? '' : 's'} selected'
                            '${rangeCount > 0 ? ' · $rangeCount range${rangeCount == 1 ? '' : 's'}' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            // Block until the weekly-off API has returned a usable set.
            if (!_hasWeeklyOffs) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Weekly offs not available yet'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              return;
            }
            final weekOffs = _weekOffsApiString(weeklyOffs!);

            // Hybrid random-date mode → carry the comma-joined date list.
            if (_isRandomMode) {
              if (_selectedHybridDates.isEmpty) {
                debugPrint('[TRIP_DETAIL] Next blocked: no random dates');
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one date'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                return;
              }
              final sorted = _selectedHybridDates.toList()..sort();
              final selectedDates = sorted.map(_formatApiDate).join(',');
              final firstDate = _formatApiDate(sorted.first);
              final lastDate = _formatApiDate(sorted.last);
              debugPrint(
                '[TRIP_DETAIL] → SelectOfficeScreen (HYBRID) '
                'selectedDates="$selectedDates" weekOffs="$weekOffs"',
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SelectOfficeScreen(
                    isLogIn: isLogIn,
                    fromDate: firstDate,
                    toDate: lastDate,
                    weekOffs: weekOffs,
                    flowArgs: widget.flowArgs,
                    useHybrid: true,
                    selectedDates: selectedDates,
                  ),
                ),
              );
              return;
            }

            final start = _rangeStartDisplay;
            final end = _rangeEndDisplay;
            debugPrint(
              '[TRIP_DETAIL] Next tapped → isLogIn=$isLogIn '
              'start=$start end=$end weeklyOffs=$weeklyOffs',
            );
            if (start == null || end == null) {
              debugPrint('[TRIP_DETAIL] Next blocked: no dates selected');
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Please select travel dates'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              return;
            }
            final fromDate = _formatApiDate(start);
            final toDate = _formatApiDate(end);
            debugPrint(
              '[TRIP_DETAIL] → SelectOfficeScreen '
              'fromDate=$fromDate toDate=$toDate weekOffs="$weekOffs"',
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectOfficeScreen(
                  isLogIn: isLogIn,
                  fromDate: fromDate,
                  toDate: toDate,
                  weekOffs: weekOffs,
                  flowArgs: widget.flowArgs,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Next',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

enum _PickerDayRole { none, single, start, middle, end }

/// Horizontally scrollable month calendar for date range selection.
class _HorizontalDateRangePicker extends StatefulWidget {
  const _HorizontalDateRangePicker({
    super.key,
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.primaryColor,
    required this.lightColor,
    required this.isSelectable,
    required this.onRangeSelected,
    this.multiSelect = false,
    this.selectedDates = const {},
    this.onDateToggled,
  });

  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color primaryColor;
  final Color lightColor;
  final bool Function(DateTime day) isSelectable;
  final ValueChanged<DateTimeRange> onRangeSelected;

  /// When `true`, tapping toggles individual days (multi-select) via
  /// [onDateToggled] and [selectedDates] drives the highlight; range selection
  /// is disabled.
  final bool multiSelect;
  final Set<DateTime> selectedDates;
  final ValueChanged<DateTime>? onDateToggled;

  @override
  State<_HorizontalDateRangePicker> createState() =>
      _HorizontalDateRangePickerState();
}

class _HorizontalDateRangePickerState
    extends State<_HorizontalDateRangePicker> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _dayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  late final PageController _pageController;
  late DateTime? _rangeStart;
  late DateTime? _rangeEnd;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get _monthCount {
    final first = widget.firstDate;
    final last = widget.lastDate;
    return (last.year - first.year) * 12 + last.month - first.month + 1;
  }

  int _monthIndex(DateTime date) {
    final first = widget.firstDate;
    return (date.year - first.year) * 12 + date.month - first.month;
  }

  DateTime _monthFromIndex(int index) {
    final first = widget.firstDate;
    return DateTime(first.year + index ~/ 12, first.month + (index % 12), 1);
  }

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialRange?.start;
    _rangeEnd = widget.initialRange?.end;
    final initialPage = _monthIndex(
      _rangeStart ?? _dateOnly(DateTime.now()),
    ).clamp(0, _monthCount - 1);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

  _PickerDayRole _dayRole(DateTime date) {
    final d = _dateOnly(date);
    if (_rangeStart == null) return _PickerDayRole.none;
    final start = _dateOnly(_rangeStart!);
    if (_rangeEnd == null) {
      return _sameDay(d, start) ? _PickerDayRole.single : _PickerDayRole.none;
    }
    final end = _dateOnly(_rangeEnd!);
    if (d.isBefore(start) || d.isAfter(end)) return _PickerDayRole.none;
    if (_sameDay(d, start) && _sameDay(d, end)) {
      return _PickerDayRole.single;
    }
    if (_sameDay(d, start)) return _PickerDayRole.start;
    if (_sameDay(d, end)) return _PickerDayRole.end;
    return _PickerDayRole.middle;
  }

  void _onDayTap(DateTime day) {
    if (!widget.isSelectable(day)) return;
    final d = _dateOnly(day);

    // Multi-select (hybrid) mode → just toggle the day; the parent owns the set.
    if (widget.multiSelect) {
      widget.onDateToggled?.call(d);
      return;
    }

    // No selection at all → first tap, select single day
    if (_rangeStart == null) {
      setState(() {
        _rangeStart = d;
        _rangeEnd = d;
      });
      widget.onRangeSelected(DateTimeRange(start: d, end: d));
      return;
    }

    final start = _dateOnly(_rangeStart!);

    // Currently a single-day selection → second tap extends to range (or keeps single)
    if (_rangeEnd != null && _sameDay(_rangeStart!, _rangeEnd!)) {
      if (_sameDay(start, d)) {
        // Tapped the same day again → keep as single
        return;
      }
      final rangeStart = d.isBefore(start) ? d : start;
      final rangeEnd = d.isBefore(start) ? start : d;
      setState(() {
        _rangeStart = rangeStart;
        _rangeEnd = rangeEnd;
      });
      widget.onRangeSelected(DateTimeRange(start: rangeStart, end: rangeEnd));
      return;
    }

    // A full range is already set → reset to new single-day selection
    setState(() {
      _rangeStart = d;
      _rangeEnd = d;
    });
    widget.onRangeSelected(DateTimeRange(start: d, end: d));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) {
              return Expanded(
                child: Center(
                  child: Text(
                    _dayLetters[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.primaryColor.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _monthCount,
            itemBuilder: (context, index) {
              return _buildMonthPage(_monthFromIndex(index));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthPage(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = DateTime(month.year, month.month, 1).weekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: Center(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const rows = 6;
                final cellHeight = constraints.maxHeight / rows;
                final cells = <Widget>[];

                for (var i = 0; i < startOffset; i++) {
                  cells.add(_emptyCell(cellHeight));
                }
                for (var day = 1; day <= daysInMonth; day++) {
                  final date = _dateOnly(
                    DateTime(month.year, month.month, day),
                  );
                  cells.add(_dayCell(date, day, cellHeight));
                }
                while (cells.length % 7 != 0) {
                  cells.add(_emptyCell(cellHeight));
                }

                final rowWidgets = <Widget>[];
                for (var r = 0; r < cells.length; r += 7) {
                  rowWidgets.add(
                    SizedBox(
                      height: cellHeight,
                      child: Row(
                        children: cells.sublist(r, r + 7),
                      ),
                    ),
                  );
                }

                return Column(children: rowWidgets);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCell(double height) {
    return Expanded(child: SizedBox(height: height));
  }

  Widget _dayCell(DateTime date, int day, double height) {
    final d = _dateOnly(date);
    final isPast = d.isBefore(_dateOnly(widget.firstDate));
    final isFuture = d.isAfter(_dateOnly(widget.lastDate));
    final isDisabled = isPast || isFuture || !widget.isSelectable(date);
    final selectable = !isDisabled;
    final isMultiSelected =
        widget.multiSelect && selectable && widget.selectedDates.contains(d);
    final role = (selectable && !widget.multiSelect)
        ? _dayRole(date)
        : _PickerDayRole.none;
    final inRange = role != _PickerDayRole.none;
    final isEndpoint = isMultiSelected ||
        role == _PickerDayRole.single ||
        role == _PickerDayRole.start ||
        role == _PickerDayRole.end;

    BorderRadius? stripRadius;
    switch (role) {
      case _PickerDayRole.start:
        stripRadius = const BorderRadius.horizontal(left: Radius.circular(18));
      case _PickerDayRole.end:
        stripRadius = const BorderRadius.horizontal(right: Radius.circular(18));
      case _PickerDayRole.middle:
        stripRadius = BorderRadius.zero;
      default:
        stripRadius = null;
    }

    return Expanded(
      child: GestureDetector(
        onTap: selectable ? () => _onDayTap(date) : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (inRange && stripRadius != null)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.lightColor,
                      borderRadius: stripRadius,
                    ),
                  ),
                ),
              if (isEndpoint)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: inRange ? FontWeight.w600 : FontWeight.w400,
                    color: isDisabled
                        ? const Color(0xFFCCCCCC)
                        : inRange
                            ? widget.primaryColor
                            : const Color(0xFF1A1A1A),
                    decoration: isPast
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: const Color(0xFFCCCCCC),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
