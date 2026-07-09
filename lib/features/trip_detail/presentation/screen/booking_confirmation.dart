import 'package:commutr_main/welcome/presentation/screen/welcome.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingConfirmedScreen extends StatefulWidget {
  /// `true` when the user updated an existing schedule (edit from welcome).
  final bool isUpdate;

  /// Message from `UpdateSchedules` API (optional).
  final String? successMessage;

  /// The selected date string (e.g. "2026-06-01"). For a Date Range this is
  /// the range start; combined with [toDate] it bounds the full range.
  final String? selectedDate;

  /// Range end for a Date Range selection (e.g. "2026-06-30"). `null`/empty for
  /// hybrid or single-date flows.
  final String? toDate;

  /// Comma-joined `yyyy-MM-dd` dates picked in the hybrid random-date flow
  /// (e.g. "2026-06-01,2026-06-03"). Only meaningful when [useHybrid] is `true`.
  final String? selectedDates;

  /// When `true`, the dates come from [selectedDates] (hybrid random-date
  /// selection). When `false`, [selectedDate]/[toDate] describe a Date Range.
  final bool useHybrid;

  /// The selected time string (e.g. "09:00 AM"). Used for the single-trip flow.
  final String? selectedTime;

  /// Login (pickup) shift time when both trips were scheduled together.
  final String? loginTime;

  /// Logout (drop) shift time when both trips were scheduled together.
  final String? logoutTime;

  const BookingConfirmedScreen({
    super.key,
    this.isUpdate = false,
    this.successMessage,
    this.selectedDate,
    this.toDate,
    this.selectedDates,
    this.useHybrid = false,
    this.selectedTime,
    this.loginTime,
    this.logoutTime,
  });

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAmPm(String raw) {
    final trimmed = raw.trim();
    // Already has AM/PM
    if (trimmed.toUpperCase().contains('AM') ||
        trimmed.toUpperCase().contains('PM')) {
      return trimmed;
    }
    // Parse HH:mm or HH:mm:ss
    final parts = trimmed.split(':');
    if (parts.isEmpty) return trimmed;
    final hour = int.tryParse(parts[0]);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hour == null || minute == null) return trimmed;
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String? formatDate(String? selectedDate) {
    if (selectedDate == null || selectedDate.isEmpty) return null;

    final date = DateTime.parse(selectedDate); // "2026-06-01"
    return DateFormat('dd-MM-yyyy').format(date); // "01-06-2026"
  }

  /// Every selected date, formatted with the existing `dd-MM-yyyy` format.
  ///
  /// Reuses the dates already chosen upstream — no re-computation of the
  /// selection itself:
  ///  • Hybrid → splits the comma-joined [BookingConfirmedScreen.selectedDates].
  ///  • Range  → expands [selectedDate]..[toDate] inclusive (the endpoints the
  ///    user picked); a single date yields just that one entry.
  List<String> _allSelectedDates() {
    if (widget.useHybrid) {
      final raw = widget.selectedDates ?? '';
      final dates = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map(DateTime.parse)
          .toList()
        ..sort();
      return dates.map((d) => DateFormat('dd-MM-yyyy').format(d)).toList();
    }

    final from = widget.selectedDate;
    if (from == null || from.isEmpty) return const [];
    final start = DateTime.parse(from);
    final toRaw = widget.toDate;
    final end = (toRaw != null && toRaw.isNotEmpty)
        ? DateTime.parse(toRaw)
        : start;

    if (!end.isAfter(start)) {
      return [DateFormat('dd-MM-yyyy').format(start)];
    }

    final result = <String>[];
    var d = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(last)) {
      result.add(DateFormat('dd-MM-yyyy').format(d));
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  /// The selected dates as a human phrase, e.g.
  /// "08-07-2026, 09-07-2026 & 10-07-2026". Built from the actual selected
  /// dates (reuses [_allSelectedDates], already `dd-MM-yyyy`) — comma-separated
  /// with an "&" before the last. Empty when nothing is selected.
  String _selectedDatesPhrase() {
    final labels = _allSelectedDates();
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    final head = labels.sublist(0, labels.length - 1).join(', ');
    return '$head & ${labels.last}';
  }

  String _buildSubtitle() {
    final date = formatDate(widget.selectedDate);
    // For multi-date bookings the subtitle names every selected date inline
    // (e.g. "08-07-2026, 09-07-2026 & 10-07-2026") instead of a single date.
    final datesPhrase = _selectedDatesPhrase();
    final hasMultipleDates = _allSelectedDates().length > 1;
    final rawLogin = widget.loginTime ?? '';
    final rawLogout = widget.logoutTime ?? '';

    // Both trips scheduled together → show login and logout timings.
    if (rawLogin.isNotEmpty || rawLogout.isNotEmpty) {
      final login = rawLogin.isNotEmpty ? _formatAmPm(rawLogin) : '';
      final logout = rawLogout.isNotEmpty ? _formatAmPm(rawLogout) : '';
      final buffer = StringBuffer();
      if (hasMultipleDates && datesPhrase.isNotEmpty) {
        buffer.write('Your ride has been scheduled for $datesPhrase.\n');
      } else if (date != null && date.isNotEmpty) {
        buffer.write('Your ride has been scheduled for $date.\n');
      } else {
        buffer.write('Your ride has been scheduled.\n');
      }
      if (login.isNotEmpty) buffer.write('Login trip schedule at $login');
      if (login.isNotEmpty && logout.isNotEmpty) buffer.write('  •  ');
      if (logout.isNotEmpty) buffer.write('Logout trip schedule at $logout');
      return buffer.toString();
    }

    final rawTime = widget.selectedTime ?? '';
    final time = rawTime.isNotEmpty ? _formatAmPm(rawTime) : '';
    if (hasMultipleDates && datesPhrase.isNotEmpty && time.isNotEmpty) {
      return 'Roster scheduled successfully for $datesPhrase at $time.';
    }
    if (date != null && date.isNotEmpty && time.isNotEmpty) {
      return 'Roster scheduled successfully for $date at $time';
    }
    return widget.isUpdate
        ? 'Your ride schedule has\nbeen successfully updated.'
        : 'Your ride schedule has been\nsuccessfully booked.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated checkmark icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5ED),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF34C769),
                            Color(0xFF1A7A38),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E8C45).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Animated text content
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Text(
                      widget.isUpdate
                          ? 'Schedule Updated!'
                          : 'Schedule Confirmed!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _buildSubtitle(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                        height: 1.6,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Back to Home button
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value * 1.5),
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to home
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Welcome(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7A3C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
