import 'package:commutr_main/trip_detail/presentation/screen/select_office.dart';
import 'package:flutter/material.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  bool isLogIn = true;
  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

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
                          // Clear selected date if it now falls on a weekly off
                          if (selectedDate != null &&
                              _isWeekOffForSet(selectedDate!, tempOffs)) {
                            selectedDate = null;
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
      final selected = selectedDate != null &&
          selectedDate!.day == day &&
          selectedDate!.month == currentMonth.month &&
          selectedDate!.year == currentMonth.year;

      cells.add(_dayCell(
        day,
        isSelected: selected,
        isWeekOff: off,
        isPast: isPast,
        onTap: (off || isPast) ? null : () => setState(() => selectedDate = date),
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
        bool isSelected = false,
        bool isWeekOff = false,
        bool isPast = false,
        VoidCallback? onTap,
      }) {
    final isDisabled = isOtherMonth || isWeekOff || isPast;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? primaryGreen : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected
                  ? Colors.white
                  : isDisabled
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final count = selectedDate != null ? 1 : 0;
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
          Text(
            'STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primaryGreen,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count day${count == 1 ? '' : 's'} selected',
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
    selectedDate = null;
  });

  void _nextMonth() => setState(() {
    currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    selectedDate = null;
  });
}