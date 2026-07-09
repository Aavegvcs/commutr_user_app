import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/screens/mobile_no_verification.dart';
import '../../bloc/shift_bloc.dart';
import '../../bloc/shift_event.dart';
import '../../bloc/shift_state.dart';
import '../../data/model/roaster_shifts_response.dart';
import '../../data/model/user_details_roaster_response.dart';
import '../../model/trip_schedule_flow_args.dart';
import 'booking_confirmation.dart';

class CommuteTimingScreen extends StatelessWidget {
  final int locCode;
  final int empId;
  final bool isLogIn;
  final String fromDate;
  final String toDate;
  final String weekOffs;
  final TripScheduleFlowArgs? flowArgs;
  final List<DrModel> drList;

  /// When `true`, the user picked arbitrary (non-contiguous) dates via the
  /// hybrid random-date selector and we call `/TransRoster/UpdateScheduleHybrid`
  /// instead of `/TransRoster/UpdateSchedules`.
  final bool useHybrid;

  /// Comma-joined `yyyy-MM-dd` dates for the hybrid call. Only meaningful when
  /// [useHybrid] is `true`.
  final String selectedDates;

  /// When `true`, the user is scheduling BOTH trips at once: a Login shift and
  /// a Logout shift are picked here (shared date range + office chosen upstream)
  /// and submitted in a single create with both `shiftStart` and `shiftEnd` set.
  /// [isLogIn] is ignored while this is `true`.
  final bool bookBoth;

  const CommuteTimingScreen({
    super.key,
    required this.locCode,
    required this.empId,
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
    this.flowArgs,
    this.drList = const [],
    this.useHybrid = false,
    this.selectedDates = '',
    this.bookBoth = false,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[COMMUTE_TIMING] init → locCode=$locCode empId=$empId '
      'isLogIn=$isLogIn fromDate=$fromDate toDate=$toDate '
      'weekOffs="$weekOffs" drList=${drList.length}',
    );
    return BlocProvider(
      create: (_) =>
          sl<ShiftBloc>()..add(FetchShifts(locCode: locCode, empId: empId)),
      child: _CommuteTimingView(
        locCode: locCode,
        empId: empId,
        isLogIn: isLogIn,
        fromDate: fromDate,
        toDate: toDate,
        weekOffs: weekOffs,
        flowArgs: flowArgs,
        drList: drList,
        useHybrid: useHybrid,
        selectedDates: selectedDates,
        bookBoth: bookBoth,
      ),
    );
  }
}

class _CommuteTimingView extends StatefulWidget {
  final int locCode;
  final int empId;
  final bool isLogIn;
  final String fromDate;
  final String toDate;
  final String weekOffs;
  final TripScheduleFlowArgs? flowArgs;
  final List<DrModel> drList;
  final bool useHybrid;
  final String selectedDates;
  final bool bookBoth;

  const _CommuteTimingView({
    required this.locCode,
    required this.empId,
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
    this.flowArgs,
    required this.drList,
    required this.useHybrid,
    required this.selectedDates,
    required this.bookBoth,
  });

  @override
  State<_CommuteTimingView> createState() => _CommuteTimingViewState();
}

class _CommuteTimingViewState extends State<_CommuteTimingView> {
  PickShift? selectedPickShift;
  DropShift? selectedDropShift;
  ShiftResult? _cachedShifts;
  bool _didApplyInitialShift = false;

  // "Apply same timing to others" state
  bool _showEmployeePanel = false;
  final Set<int> _selectedEmpIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color primaryGreen = Color(0xFF1A6B4A);
  static const Color lightGreen = Color(0xFFB2D8C8);

  @override
  void initState() {
    super.initState();
    _selectedEmpIds.add(widget.empId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _showError(String message) {
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
  }

  void _applyPreselectedShift(ShiftResult result) {
    if (_didApplyInitialShift) return;
    _didApplyInitialShift = true;

    final preset = widget.flowArgs?.preselectedShiftTime;

    // Both mode: default-select the first future pick AND the first future drop
    // so the user can immediately proceed (or change either). No flowArgs preset
    // applies here since "Both" is create-only.
    if (widget.bookBoth) {
      final pick = _firstFuturePick(result.pickShifts);
      final drop = _firstFutureDrop(result.dropShifts);
      setState(() {
        if (pick != null) selectedPickShift = pick;
        if (drop != null) selectedDropShift = drop;
      });
      debugPrint(
        '[COMMUTE_TIMING] pre-selected both '
        'pick=${pick?.shiftId}/"${pick?.shiftTime}" '
        'drop=${drop?.shiftId}/"${drop?.shiftTime}"',
      );
      return;
    }

    if (widget.isLogIn) {
      PickShift? pick;
      if (preset != null && preset.isNotEmpty) {
        for (final s in result.pickShifts) {
          if (shiftTimesMatch(s.shiftTime, preset)) {
            pick = s;
            break;
          }
        }
      }
      pick ??= _firstFuturePick(result.pickShifts);
      if (pick != null && selectedPickShift?.shiftId != pick.shiftId) {
        setState(() => selectedPickShift = pick);
        debugPrint(
          '[COMMUTE_TIMING] pre-selected pick '
          'id=${pick.shiftId} time="${pick.shiftTime}"',
        );
      }
      return;
    }

    DropShift? drop;
    if (preset != null && preset.isNotEmpty) {
      for (final s in result.dropShifts) {
        if (shiftTimesMatch(s.shiftTime, preset)) {
          drop = s;
          break;
        }
      }
    }
    drop ??= _firstFutureDrop(result.dropShifts);
    if (drop != null && selectedDropShift?.shiftId != drop.shiftId) {
      setState(() => selectedDropShift = drop);
      debugPrint(
        '[COMMUTE_TIMING] pre-selected drop '
        'id=${drop.shiftId} time="${drop.shiftTime}"',
      );
    }
  }

  void _submitSchedule() {
    // In "Both" mode both timings are sent in a single create: shiftStart from
    // the Login (pick) shift and shiftEnd from the Logout (drop) shift. In the
    // single-trip flow exactly one timing is set and the other is "NA".
    final String shiftStart;
    final String shiftEnd;
    if (widget.bookBoth) {
      shiftStart = selectedPickShift?.shiftTime ?? '';
      shiftEnd = selectedDropShift?.shiftTime ?? '';
    } else {
      shiftStart =
          widget.isLogIn ? (selectedPickShift?.shiftTime ?? '') : "NA";
      shiftEnd =
          widget.isLogIn ? "NA" : (selectedDropShift?.shiftTime ?? '');
    }

    // Always include self; append any selected DR emp IDs
    final allIds = <int>{widget.empId, ..._selectedEmpIds};
    final userEmpIds = allIds.join(',');

    // Hybrid flow: arbitrary (non-contiguous) dates were picked upstream, so
    // call /TransRoster/UpdateScheduleHybrid with the comma-joined date list
    // instead of the contiguous from/to range.
    if (widget.useHybrid) {
      debugPrint(
        '[COMMUTE_TIMING] Next tapped (HYBRID) → '
        'isLogIn=${widget.isLogIn} '
        'locCode=${widget.locCode} '
        'empId=${widget.empId} '
        'selectedDates="${widget.selectedDates}" '
        'weekOffs="${widget.weekOffs}" '
        'selectedPickShift=${selectedPickShift?.shiftId}/"${selectedPickShift?.shiftTime}" '
        'selectedDropShift=${selectedDropShift?.shiftId}/"${selectedDropShift?.shiftTime}" '
        '→ shiftStart="$shiftStart" shiftEnd="$shiftEnd" '
        '→ userEmpIds="$userEmpIds"',
      );

      context.read<ShiftBloc>().add(
            UpdateHybridSchedules(
              locCode: widget.locCode,
              selectedDates: widget.selectedDates,
              shiftStart: shiftStart,
              shiftEnd: shiftEnd,
              weekOffs: "",
              userEmpIds: userEmpIds,
            ),
          );
      return;
    }

    debugPrint(
      '[COMMUTE_TIMING] Next tapped → '
      'isLogIn=${widget.isLogIn} '
      'locCode=${widget.locCode} '
      'empId=${widget.empId} '
      'fromDate=${widget.fromDate} '
      'toDate=${widget.toDate} '
      'weekOffs="${widget.weekOffs}" '
      'selectedPickShift=${selectedPickShift?.shiftId}/"${selectedPickShift?.shiftTime}" '
      'selectedDropShift=${selectedDropShift?.shiftId}/"${selectedDropShift?.shiftTime}" '
      '→ shiftStart="$shiftStart" shiftEnd="$shiftEnd" '
      '→ userEmpIds="$userEmpIds"',
    );

    context.read<ShiftBloc>().add(
          UpdateShiftSchedules(
            locCode: widget.locCode,
            fromDate: widget.fromDate,
            toDate: widget.toDate,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            weekOffs: "",
            userEmpIds: userEmpIds,
          ),
        );
  }

  String _selectedCountLabel() {
    final count = _selectedEmpIds.length;
    if (count == 0) return 'Select employees';
    if (count == 1) return '1 employee selected';
    return '$count employees selected';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Parses a `HH:mm` (24-hour) shift string into minutes-since-midnight.
  /// Returns `null` when the string can't be parsed.
  int? _shiftMinutes(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Whether the schedule's start date is today, in which case shift times
  /// that have already elapsed should be hidden. For future dates every shift
  /// is still valid, so no filtering is applied.
  bool get _isToday {
    final from = parseIsoDate(widget.fromDate);
    if (from == null) return false;
    final now = DateTime.now();
    return from.year == now.year &&
        from.month == now.month &&
        from.day == now.day;
  }

  /// True when [time] has not yet passed (or [fromDate] isn't today).
  bool _isFutureTime(String time) {
    if (!_isToday) return true;
    final mins = _shiftMinutes(time);
    if (mins == null) return true;
    final now = DateTime.now();
    return mins > now.hour * 60 + now.minute;
  }

  /// Filters out shifts whose time has already passed when [fromDate] is today.
  List<({int id, String time})> _futureShifts(
          List<({int id, String time})> shifts) =>
      shifts.where((s) => _isFutureTime(s.time)).toList();

  /// First pick shift that hasn't elapsed yet, or `null` when none remain.
  PickShift? _firstFuturePick(List<PickShift> shifts) {
    for (final s in shifts) {
      if (_isFutureTime(s.shiftTime)) return s;
    }
    return null;
  }

  /// First drop shift that hasn't elapsed yet, or `null` when none remain.
  DropShift? _firstFutureDrop(List<DropShift> shifts) {
    for (final s in shifts) {
      if (_isFutureTime(s.shiftTime)) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: BlocConsumer<ShiftBloc, ShiftState>(
          listener: (context, state) {
            debugPrint(
              '[COMMUTE_TIMING] listener state=${state.runtimeType}',
            );
            if (state is ShiftLoaded) {
              setState(() => _cachedShifts = state.result);
              _applyPreselectedShift(state.result);
            } else if (state is ShiftUnauthorized) {
              debugPrint('[COMMUTE_TIMING] session expired → ${state.message}');
              _handleSessionExpired(state.message);
            } else if (state is ShiftUpdateSuccess) {
              debugPrint(
                '[COMMUTE_TIMING] update success → '
                'navigating to BookingConfirmedScreen ("${state.message}")',
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingConfirmedScreen(
                    isUpdate: widget.flowArgs?.isEdit == true,
                    successMessage: state.message,
                    selectedDate: widget.fromDate,
                    // Reuse the dates already selected upstream so the
                    // confirmation can list every selected date:
                    //  • Hybrid  → the comma-joined `selectedDates` list.
                    //  • Range   → the from/to endpoints (expanded on display).
                    toDate: widget.toDate,
                    selectedDates: widget.selectedDates,
                    useHybrid: widget.useHybrid,
                    selectedTime: widget.bookBoth
                        ? null
                        : widget.isLogIn
                            ? selectedPickShift?.shiftTime
                            : selectedDropShift?.shiftTime,
                    loginTime: widget.bookBoth
                        ? selectedPickShift?.shiftTime
                        : null,
                    logoutTime: widget.bookBoth
                        ? selectedDropShift?.shiftTime
                        : null,
                  ),
                ),
              );
            } else if (state is ShiftUpdateError) {
              debugPrint('[COMMUTE_TIMING] update error → ${state.message}');
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isUpdating = state is ShiftUpdateInProgress;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isUpdating
                            ? null
                            : () => Navigator.maybePop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: primaryGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Commute Timing',
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Row(
                    children: List.generate(4, (index) {
                      return Expanded(
                        child: Container(
                          margin:
                              EdgeInsets.only(right: index < 3 ? 8 : 0),
                          height: 6,
                          decoration: BoxDecoration(
                            color:
                                index < 3 ? primaryGreen : lightGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 24),

                Expanded(child: _buildContent(state)),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isNextDisabled(state)
                          ? null
                          : _submitSchedule,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: isUpdating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isNextDisabled(ShiftState state) {
    if (state is ShiftUpdateInProgress) return true;
    if (_cachedShifts == null) return true;
    if (_selectedEmpIds.isEmpty) return true;
    if (widget.bookBoth) {
      return selectedPickShift == null || selectedDropShift == null;
    }
    return widget.isLogIn
        ? selectedPickShift == null
        : selectedDropShift == null;
  }

  Widget _buildContent(ShiftState state) {
    if (_cachedShifts == null) {
      if (state is ShiftInitial || state is ShiftLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state is ShiftUnauthorized) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    color: primaryGreen, size: 40),
                const SizedBox(height: 12),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF7A9A8A), fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
      if (state is ShiftError) {
        return Center(
          child: Text(
            state.message,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final cached = _cachedShifts!;
    final screenHeight = MediaQuery.of(context).size.height;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.bookBoth) ...[
            // Both trips: a Login shift card and a Logout shift card, submitted
            // together as one create with both shiftStart and shiftEnd set.
            SizedBox(
              height: screenHeight * 0.22,
              child: _ShiftCard(
                title: 'Login Timing',
                // subtitle: 'Daily commute to office',
                shifts: _futureShifts(cached.pickShifts
                    .map((s) => (id: s.shiftId, time: s.shiftTime))
                    .toList()),
                selectedId: selectedPickShift?.shiftId,
                onSelect: (id) => setState(() => selectedPickShift =
                    cached.pickShifts.firstWhere((s) => s.shiftId == id)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: screenHeight * 0.22,
              child: _ShiftCard(
                title: 'Logout Timing',
                // subtitle: 'Daily commute from office',
                shifts: _futureShifts(cached.dropShifts
                    .map((s) => (id: s.shiftId, time: s.shiftTime))
                    .toList()),
                selectedId: selectedDropShift?.shiftId,
                onSelect: (id) => setState(() => selectedDropShift =
                    cached.dropShifts.firstWhere((s) => s.shiftId == id)),
              ),
            ),
          ] else
            SizedBox(
              height: screenHeight * 0.32,
              child: widget.isLogIn
                  ? _ShiftCard(
                      title: 'Login Timing',
                      // subtitle: 'Daily commute to office',
                      shifts: _futureShifts(cached.pickShifts
                          .map((s) => (id: s.shiftId, time: s.shiftTime))
                          .toList()),
                      selectedId: selectedPickShift?.shiftId,
                      onSelect: (id) => setState(() => selectedPickShift =
                          cached.pickShifts
                              .firstWhere((s) => s.shiftId == id)),
                    )
                  : _ShiftCard(
                      title: 'Logout Timing',
                      // subtitle: 'Daily commute from office',
                      shifts: _futureShifts(cached.dropShifts
                          .map((s) => (id: s.shiftId, time: s.shiftTime))
                          .toList()),
                      selectedId: selectedDropShift?.shiftId,
                      onSelect: (id) => setState(() => selectedDropShift =
                          cached.dropShifts
                              .firstWhere((s) => s.shiftId == id)),
                    ),
            ),

          if (widget.drList.length > 1) ...[
            const SizedBox(height: 24),
            _buildApplyToOthersSection(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildApplyToOthersSection() {
    final selectedCount = _selectedEmpIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Apply same timing to other employees',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),

        // Summary pill / trigger row
        GestureDetector(
          onTap: () => setState(() => _showEmployeePanel = !_showEmployeePanel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  color: primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCountLabel(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF444444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: lightGreen.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    selectedCount == 0
                        ? '0 selected'
                        : '$selectedCount selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _showEmployeePanel ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF888888),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expandable employee list
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showEmployeePanel
              ? _buildEmployeePanel()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildEmployeePanel() {
    // The logged-in user is already present in `drList` (matched by empId), so
    // render it directly — no synthetic "You" entry to avoid a duplicate row.
    final filtered = _searchQuery.isEmpty
        ? widget.drList
        : widget.drList
            .where((e) =>
                e.empName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search employees...',
                hintStyle: const TextStyle(
                    color: Color(0xFFAAAAAA), fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFAAAAAA),
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // DR list
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No employees found',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, indent: 16, endIndent: 16,
                  color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final emp = filtered[index];
                final isSelected = _selectedEmpIds.contains(emp.empId);
                return _EmployeeRow(
                  initials: _initials(emp.empName),
                  name: emp.empName,
                  isSelected: isSelected,
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedEmpIds.remove(emp.empId);
                    } else {
                      _selectedEmpIds.add(emp.empId);
                    }
                  }),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final String initials;
  final String name;
  final bool isSelected;
  final VoidCallback? onTap;

  static const Color _primaryGreen = Color(0xFF1A6B4A);
  static const Color _lightGreen = Color(0xFFB2D8C8);

  const _EmployeeRow({
    required this.initials,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _lightGreen.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _primaryGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: _primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFCCCCCC),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatefulWidget {
  final String title;
  // final String subtitle;
  final List<({int id, String time})> shifts;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _ShiftCard({
    required this.title,
    // required this.subtitle,
    required this.shifts,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  final ScrollController _scrollController = ScrollController();

  static const Color _primaryGreen = Color(0xFF1A6B4A);
  static const Color _lightGreen = Color(0xFFB2D8C8);
  static const Color _unselected = Color(0xFFAAAAAA);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Formats a `HH:mm` (24-hour) shift string into a 12-hour AM/PM label for
  /// display only. Returns the original string when it can't be parsed.
  String _formatAmPm(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return raw;
    final period = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _lightGreen.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          // const SizedBox(height: 4),
          // Text(
          //   widget.subtitle,
          //   style: const TextStyle(
          //     fontSize: 13,
          //     color: Color(0xFF888888),
          //     fontWeight: FontWeight.w400,
          //   ),
          // ),
          const SizedBox(height: 20),
          Expanded(
            child: widget.shifts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.schedule_outlined,
                          color: _unselected,
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No shift timings available',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF888888),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'There are no shift timings for the selected date. Please choose a different date.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                  )
                : RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thumbColor: const Color(0xFF9AA5B1).withValues(alpha: 0.6),
                    radius: const Radius.circular(12),
                    thickness: 5,
                    // Inset the thumb so it floats neatly at the card's edge
                    // and doesn't overlap the shift tiles.
                    padding: const EdgeInsets.only(right: 2, top: 4, bottom: 4),
                    child: GridView.builder(
                      controller: _scrollController,
                      // Room on the right so tiles don't sit under the thumb.
                      padding: const EdgeInsets.only(right: 10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 3.2,
                      ),
                      itemCount: widget.shifts.length,
                      itemBuilder: (context, index) {
                        final shift = widget.shifts[index];
                        final isSelected = widget.selectedId == shift.id;
                        return GestureDetector(
                          onTap: () => widget.onSelect(shift.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _primaryGreen
                                  : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? _primaryGreen
                                    : const Color(0xFFEEEEEE),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _formatAmPm(shift.time),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
