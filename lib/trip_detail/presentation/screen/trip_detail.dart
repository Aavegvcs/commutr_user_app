import 'package:commutr_main/trip_detail/presentation/screen/select_office.dart';
import 'package:flutter/material.dart';

enum _DayRangeRole { none, single, start, middle, end, anchor }

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  bool isLogIn = true;
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// One-day selection (first tap, or confirmed with second tap on same day).
  DateTime? _selectedSingleDate;

  /// Completed ranges (inclusive start/end, date-only).
  List<DateTimeRange> _selectedRanges = [];

  /// First tap while building a range; second tap completes it.
  DateTime? _rangeAnchor;

  // 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
  Set<int> weeklyOffs = {0, 6}; // Sun & Sat by default

  final Color primaryGreen = const Color(0xFF1A6B3C);
  final Color lightGreen = const Color(0xFFE8F5EE);
  final Color borderGreen = const Color(0xFFB8DEC9);

  static const List<String> _dayLabels = [
    'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'
  ];
  static const List<String> _dayFull = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  // Flutter's date.weekday: Mon=1 ... Sat=6, Sun=7  →  map to 0=Sun..6=Sat
  bool _isWeekOff(DateTime date) => weeklyOffs.contains(date.weekday % 7);
  bool _isWeekOffForSet(DateTime date, Set<int> offs) =>
      offs.contains(date.weekday % 7);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      _dateOnly(a) == _dateOnly(b);

  bool _isAnchor(DateTime date) =>
      _rangeAnchor != null && _sameDay(_rangeAnchor!, date);

  bool _isDateInRanges(DateTime date) {
    final d = _dateOnly(date);
    for (final r in _selectedRanges) {
      final rs = _dateOnly(r.start);
      final re = _dateOnly(r.end);
      if (!d.isBefore(rs) && !d.isAfter(re)) return true;
    }
    return false;
  }

  _DayRangeRole _dayRangeRole(DateTime date) {
    final d = _dateOnly(date);
    if (_isAnchor(date)) return _DayRangeRole.anchor;
    for (final r in _selectedRanges) {
      final rs = _dateOnly(r.start);
      final re = _dateOnly(r.end);
      if (d.isBefore(rs) || d.isAfter(re)) continue;
      if (_sameDay(rs, re)) return _DayRangeRole.single;
      if (_sameDay(d, rs)) return _DayRangeRole.start;
      if (_sameDay(d, re)) return _DayRangeRole.end;
      return _DayRangeRole.middle;
    }
    if (_selectedSingleDate != null &&
        _sameDay(_selectedSingleDate!, d) &&
        !_isDateInRanges(date)) {
      return _DayRangeRole.single;
    }
    return _DayRangeRole.none;
  }

  int _totalSelectedDayCount() {
    int n = 0;
    for (final r in _selectedRanges) {
      n += r.end.difference(r.start).inDays + 1;
    }
    if (_selectedRanges.isEmpty &&
        _selectedSingleDate != null &&
        _rangeAnchor == null) {
      n = 1;
    } else if (_rangeAnchor != null && _selectedRanges.isEmpty) {
      n = 1;
    }
    return n;
  }

  bool get _hasOnlySingleDate =>
      _selectedSingleDate != null &&
      _selectedRanges.isEmpty &&
      _rangeAnchor == null;

  String _formatShortDate(DateTime? date) {
    if (date == null) return '—';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final w = _dayLabels[date.weekday % 7];
    return '${date.day} ${months[date.month - 1]}, $w';
  }

  DateTime? get _rangeStartDisplay {
    if (_rangeAnchor != null) return _rangeAnchor;
    if (_selectedRanges.isNotEmpty) return _selectedRanges.last.start;
    return _selectedSingleDate;
  }

  DateTime? get _rangeEndDisplay {
    if (_rangeAnchor != null) return null;
    if (_selectedRanges.isNotEmpty) return _selectedRanges.last.end;
    return _selectedSingleDate;
  }

  /// Merges overlapping or adjacent (touching) ranges.
  List<DateTimeRange> _mergeRanges(List<DateTimeRange> ranges) {
    if (ranges.isEmpty) return [];
    final sorted = [...ranges]
      ..sort((a, b) => a.start.compareTo(b.start));
    final out = <DateTimeRange>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final cur = sorted[i];
      final last = out.last;
      final lastEndPlus1 = last.end.add(const Duration(days: 1));
      if (!cur.start.isAfter(lastEndPlus1)) {
        out.removeLast();
        out.add(DateTimeRange(
          start: last.start,
          end: cur.end.isAfter(last.end) ? cur.end : last.end,
        ));
      } else {
        out.add(cur);
      }
    }
    return out;
  }

  void _onCalendarDayTapped(DateTime date) {
    final d = _dateOnly(date);

    if (_rangeAnchor != null) {
      final a = _dateOnly(_rangeAnchor!);
      if (_sameDay(a, d)) {
        setState(() {
          _selectedSingleDate = d;
          _selectedRanges = [];
          _rangeAnchor = null;
        });
        return;
      }
      final start = d.isBefore(a) ? d : a;
      final end = d.isBefore(a) ? a : d;
      setState(() {
        _selectedSingleDate = null;
        _selectedRanges = _mergeRanges([
          ..._selectedRanges,
          DateTimeRange(start: start, end: end),
        ]);
        _rangeAnchor = null;
      });
      return;
    }

    if (_hasOnlySingleDate && _sameDay(_selectedSingleDate!, d)) {
      setState(() => _selectedSingleDate = null);
      return;
    }

    setState(() {
      _rangeAnchor = d;
      _selectedSingleDate = _selectedRanges.isEmpty ? d : null;
    });
  }

  void _clearAllDateSelections() {
    setState(() {
      _selectedSingleDate = null;
      _selectedRanges = [];
      _rangeAnchor = null;
    });
  }

  // ─── Bottom sheet ──────────────────────────────────────────────────────────
  void _showEditWeeklyOffsSheet() {
    Set<int> tempOffs = Set.from(weeklyOffs);

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
            20, 12, 20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
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
                    width: 36, height: 36,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
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
                          if (_rangeAnchor != null &&
                              _isWeekOffForSet(_rangeAnchor!, tempOffs)) {
                            _rangeAnchor = null;
                          }
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

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const SizedBox(height: 24),
                    _buildDateFields(),
                    const SizedBox(height: 16),
                    _buildCalendar(),
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.arrow_back, color: primaryGreen, size: 22),
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
          _buildToggleBtn('Log In', isLogIn),
          _buildToggleBtn('Logout', !isLogIn),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isLogIn = label == 'Log In'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
    final sortedOffs = weeklyOffs.toList()..sort();
    return GestureDetector(
      onTap: _showEditWeeklyOffsSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
        ),
        child: Row(
          children: [
            // Calendar icon
            Container(
              width: 38, height: 38,
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
            const Spacer(),
            // Day chips (scrollable if many days)
            Row(
              spacing: 6,
              children: sortedOffs
                  .map((i) => _buildChip(_dayLabels[i]))
                  .toList(),
            ),
          ],
        ),
      ),
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

  Widget _buildDateFields() {
    final hasSelection =
        _rangeStartDisplay != null || _rangeEndDisplay != null;
    return Row(
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
        Icon(Icons.arrow_forward, size: 18, color: primaryGreen.withOpacity(0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: _dateFieldBox(
            label: 'TO',
            value: _rangeAnchor != null
                ? 'Select end'
                : _formatShortDate(_rangeEndDisplay),
            isPlaceholder: _rangeEndDisplay == null && _rangeAnchor == null,
            isActive: hasSelection && _rangeAnchor == null,
          ),
        ),
      ],
    );
  }

  Widget _dateFieldBox({
    required String label,
    required String value,
    required bool isPlaceholder,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              color: primaryGreen.withOpacity(0.7),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPlaceholder ? 'Tap to select' : value,
            style: TextStyle(
              fontSize: 15,
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

  Widget _buildCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month + nav
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _monthYear(currentMonth),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _prevMonth,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left,
                        size: 24, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _nextMonth,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right,
                        size: 24, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0F0F0), width: 1),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildDayHeaders(),
              const SizedBox(height: 8),
              _buildDayGrid(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders() {
    const letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: List.generate(7, (i) {
        final isOff = weeklyOffs.contains(i);
        return Expanded(
          child: Center(
            child: Text(
              letters[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isOff
                    ? primaryGreen.withOpacity(0.45)
                    : const Color(0xFF999999),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDayGrid() {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // 0=Sun
    final prevMonthDays =
        DateTime(currentMonth.year, currentMonth.month, 0).day;

    // Normalize today to midnight for accurate date comparison
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    List<Widget> rows = [];
    List<Widget> cells = [];

    // Trailing days of prev month
    for (int i = 0; i < startOffset; i++) {
      cells.add(_dayCell(prevMonthDays - startOffset + 1 + i,
          isOtherMonth: true));
    }

    // Current month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final off = _isWeekOff(date);
      final isPast = date.isBefore(todayOnly);
      final role = _dayRangeRole(date);

      cells.add(_dayCell(
        day,
        role: role,
        isWeekOff: off,
        isPast: isPast,
        onTap: (off || isPast) ? null : () => _onCalendarDayTapped(date),
      ));

      if (cells.length == 7) {
        rows.add(Row(children: List.from(cells)));
        cells = [];
      }
    }

    // Leading days of next month
    if (cells.isNotEmpty) {
      int n = 1;
      while (cells.length < 7) cells.add(_dayCell(n++, isOtherMonth: true));
      rows.add(Row(children: List.from(cells)));
    }

    return Column(children: rows);
  }

  Widget _dayCell(
    int day, {
    bool isOtherMonth = false,
    _DayRangeRole role = _DayRangeRole.none,
    bool isWeekOff = false,
    bool isPast = false,
    VoidCallback? onTap,
  }) {
    final isDisabled = isOtherMonth || isWeekOff || isPast;
    final inSelection = role != _DayRangeRole.none;
    final isEndpoint = role == _DayRangeRole.single ||
        role == _DayRangeRole.start ||
        role == _DayRangeRole.end ||
        role == _DayRangeRole.anchor;
    final isAnchor = role == _DayRangeRole.anchor;

    BorderRadius? stripRadius;
    switch (role) {
      case _DayRangeRole.start:
        stripRadius = const BorderRadius.horizontal(left: Radius.circular(22));
      case _DayRangeRole.end:
        stripRadius = const BorderRadius.horizontal(right: Radius.circular(22));
      case _DayRangeRole.middle:
        stripRadius = BorderRadius.zero;
      default:
        stripRadius = null;
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (inSelection && stripRadius != null)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: stripRadius,
                    ),
                  ),
                ),
              if (isEndpoint)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isAnchor
                        ? primaryGreen.withOpacity(0.25)
                        : primaryGreen,
                    shape: BoxShape.circle,
                    border: isAnchor
                        ? Border.all(color: primaryGreen, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isAnchor
                          ? primaryGreen
                          : Colors.white,
                    ),
                  ),
                )
              else
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: inSelection ? FontWeight.w600 : FontWeight.w400,
                    color: inSelection
                        ? primaryGreen
                        : isDisabled
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF1A1A1A),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final count = _totalSelectedDayCount();
    final rangeCount = _selectedRanges.length;
    final hasAnchor = _rangeAnchor != null;
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
              if (count > 0 || hasAnchor)
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
                ? 'Tap a date to select'
                : _hasOnlySingleDate
                    ? 'Travel on ${_formatShortDate(_selectedSingleDate)}'
                    : '$count day${count == 1 ? '' : 's'} selected'
                        '${rangeCount > 0 ? ' · $rangeCount range${rangeCount == 1 ? '' : 's'}' : ''}'
                        '${hasAnchor ? ' · tap end date' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (hasAnchor) ...[
            const SizedBox(height: 8),
            Text(
              'Tap same date for one day, or another date for a range',
              style: TextStyle(
                fontSize: 12,
                color: primaryGreen.withOpacity(0.85),
              ),
            ),
          ],
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectOfficeScreen(),
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

  String _monthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _prevMonth() => setState(() {
    currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
  });
}