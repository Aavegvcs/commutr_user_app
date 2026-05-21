import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/screens/mobile_no_verification.dart';
import '../../bloc/shift_bloc.dart';
import '../../bloc/shift_event.dart';
import '../../bloc/shift_state.dart';
import '../../data/model/roaster_shifts_response.dart';
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

  const CommuteTimingScreen({
    super.key,
    required this.locCode,
    required this.empId,
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
    this.flowArgs,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[COMMUTE_TIMING] init → locCode=$locCode empId=$empId '
      'isLogIn=$isLogIn fromDate=$fromDate toDate=$toDate '
      'weekOffs="$weekOffs"',
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

  const _CommuteTimingView({
    required this.locCode,
    required this.empId,
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
    this.flowArgs,
  });

  @override
  State<_CommuteTimingView> createState() => _CommuteTimingViewState();
}

class _CommuteTimingViewState extends State<_CommuteTimingView> {
  PickShift? selectedPickShift;
  DropShift? selectedDropShift;
  ShiftResult? _cachedShifts;
  bool _didApplyInitialShift = false;

  static const Color primaryGreen = Color(0xFF1A6B4A);
  static const Color lightGreen = Color(0xFFB2D8C8);

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
      '→ shiftStart="$shiftStart" shiftEnd="$shiftEnd"',
    );

    context.read<ShiftBloc>().add(
          UpdateShiftSchedules(
            locCode: widget.locCode,
            fromDate: widget.fromDate,
            toDate: widget.toDate,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            weekOffs: "",
            userEmpIds: widget.empId.toString(),
          ),
        );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (widget.isLogIn)
            _ShiftCard(
              title: 'Login Timing',
              subtitle: 'Daily commute to office',
              shifts: cached.pickShifts
                  .map((s) => (id: s.shiftId, time: s.shiftTime))
                  .toList(),
              selectedId: selectedPickShift?.shiftId,
              onSelect: (id) => setState(() => selectedPickShift = cached
                  .pickShifts
                  .firstWhere((s) => s.shiftId == id)),
            ),
          if (!widget.isLogIn)
            _ShiftCard(
              title: 'Logout Timing',
              subtitle: 'Daily commute from office',
              shifts: cached.dropShifts
                  .map((s) => (id: s.shiftId, time: s.shiftTime))
                  .toList(),
              selectedId: selectedDropShift?.shiftId,
              onSelect: (id) => setState(() => selectedDropShift = cached
                  .dropShifts
                  .firstWhere((s) => s.shiftId == id)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<({int id, String time})> shifts;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  static const Color _primaryGreen = Color(0xFF1A6B4A);
  static const Color _lightGreen = Color(0xFFB2D8C8);
  static const Color _unselected = Color(0xFFAAAAAA);

  const _ShiftCard({
    required this.title,
    required this.subtitle,
    required this.shifts,
    required this.selectedId,
    required this.onSelect,
  });

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
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.2,
            ),
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              final isSelected = selectedId == shift.id;
              return GestureDetector(
                onTap: () => onSelect(shift.id),
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
        ],
      ),
    );
  }
}
