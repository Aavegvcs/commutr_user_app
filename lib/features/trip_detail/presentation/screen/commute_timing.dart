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

  const _CommuteTimingView({
    required this.locCode,
    required this.empId,
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
    this.flowArgs,
    required this.drList,
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
      pick ??= result.pickShifts.isNotEmpty ? result.pickShifts.first : null;
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
    drop ??= result.dropShifts.isNotEmpty ? result.dropShifts.first : null;
    if (drop != null && selectedDropShift?.shiftId != drop.shiftId) {
      setState(() => selectedDropShift = drop);
      debugPrint(
        '[COMMUTE_TIMING] pre-selected drop '
        'id=${drop.shiftId} time="${drop.shiftTime}"',
      );
    }
  }

  void _submitSchedule() {
    final shiftStart =
        widget.isLogIn ? (selectedPickShift?.shiftTime ?? '') : "NA";
    final shiftEnd =
        widget.isLogIn ? "NA" : (selectedDropShift?.shiftTime ?? '');

    // Always include self; append any selected DR emp IDs
    final allIds = <int>{widget.empId, ..._selectedEmpIds};
    final userEmpIds = allIds.join(',');

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
                    selectedTime: widget.isLogIn
                        ? selectedPickShift?.shiftTime
                        : selectedDropShift?.shiftTime,
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
          SizedBox(
            height: screenHeight * 0.40,
            child: widget.isLogIn
                ? _ShiftCard(
                    title: 'Login Timing',
                    subtitle: 'Daily commute to office',
                    shifts: cached.pickShifts
                        .map((s) => (id: s.shiftId, time: s.shiftTime))
                        .toList(),
                    selectedId: selectedPickShift?.shiftId,
                    onSelect: (id) => setState(() => selectedPickShift =
                        cached.pickShifts
                            .firstWhere((s) => s.shiftId == id)),
                  )
                : _ShiftCard(
                    title: 'Logout Timing',
                    subtitle: 'Daily commute from office',
                    shifts: cached.dropShifts
                        .map((s) => (id: s.shiftId, time: s.shiftTime))
                        .toList(),
                    selectedId: selectedDropShift?.shiftId,
                    onSelect: (id) => setState(() => selectedDropShift =
                        cached.dropShifts
                            .firstWhere((s) => s.shiftId == id)),
                  ),
          ),

          if (widget.drList.length > 1) ...[
            const SizedBox(height: 28),
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
          'Apply same timing to others',
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
    // Prepend a synthetic "You" entry so self is always visible and toggleable
    final selfEntry = DrModel(empId: widget.empId, empName: 'You');
    final drOnly = _searchQuery.isEmpty
        ? widget.drList
        : widget.drList
            .where((e) => e.empName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    final filtered = [
      if (_searchQuery.isEmpty ||
          'you'.contains(_searchQuery.toLowerCase()))
        selfEntry,
      ...drOnly,
    ];

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
  final String subtitle;
  final List<({int id, String time})> shifts;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _ShiftCard({
    required this.title,
    required this.subtitle,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: GridView.builder(
                controller: _scrollController,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        color: isSelected ? _primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        shift.time,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _unselected,
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
