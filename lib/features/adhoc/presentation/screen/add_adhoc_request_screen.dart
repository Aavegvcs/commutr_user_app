import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/adhoc/bloc/adhoc_bloc.dart';
import 'package:commutr_main/features/adhoc/bloc/adhoc_event.dart';
import 'package:commutr_main/features/adhoc/bloc/adhoc_state.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/shift_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/roaster_shifts_response.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_details_roaster_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddAdhocRequestScreen extends StatelessWidget {
  const AddAdhocRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<RosterBloc>()..add(const FetchRosterUserDetails()),
        ),
        BlocProvider(create: (_) => sl<ShiftBloc>()),
        BlocProvider(create: (_) => sl<AdhocBloc>()),
      ],
      child: const _AddAdhocRequestView(),
    );
  }
}

class _AddAdhocRequestView extends StatefulWidget {
  const _AddAdhocRequestView();

  @override
  State<_AddAdhocRequestView> createState() => _AddAdhocRequestViewState();
}

class _AddAdhocRequestViewState extends State<_AddAdhocRequestView> {
  static const _green = Color(0xFF1A6B3C);
  static const _bg = Color(0xFFFFFFFF);
  static const _fieldBg = Color(0xFFF5F5F4);
  static const _labelColor = Color(0xFF1A3C2B);
  static const _lightGreen = Color(0xFFE8F5EE);

  DateTime _scheduleDate = DateTime.now();
  bool _isLogin = true;

  // Office location selection
  int _selectedLocationIndex = 0;
  bool _didApplyInitialLocation = false;

  // Shift selection
  PickShift? _selectedPickShift;
  DropShift? _selectedDropShift;
  ShiftResult? _cachedShifts;

  // Member selection (multi-select via drList)
  final Set<int> _selectedMemberIndices = {};

  final TextEditingController _remarksController = TextEditingController();

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String _formatApiDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
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

  void _onLocationSelected(int index, List<LocationModel> locations) {
    if (_selectedLocationIndex == index) return;
    setState(() {
      _selectedLocationIndex = index;
      _selectedPickShift = null;
      _selectedDropShift = null;
      _cachedShifts = null;
    });
    final rosterState = context.read<RosterBloc>().state;
    if (rosterState is RosterLoaded) {
      final empId = rosterState.details.empId;
      final locCode = locations[index].locCode;
      context.read<ShiftBloc>().add(FetchShifts(locCode: locCode, empId: empId));
    }
  }

  void _fetchShiftsIfReady() {
    final rosterState = context.read<RosterBloc>().state;
    if (rosterState is! RosterLoaded) return;
    final locations = rosterState.details.locations;
    if (locations.isEmpty) return;
    final idx = _selectedLocationIndex.clamp(0, locations.length - 1);
    final locCode = locations[idx].locCode;
    final empId = rosterState.details.empId;
    context.read<ShiftBloc>().add(FetchShifts(locCode: locCode, empId: empId));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RosterBloc, RosterState>(
          listener: (context, state) {
            if (state is RosterUnauthorized) {
              _handleSessionExpired(state.message);
            } else if (state is RosterLoaded && !_didApplyInitialLocation) {
              _didApplyInitialLocation = true;
              _fetchShiftsIfReady();
            }
          },
        ),
        BlocListener<ShiftBloc, ShiftState>(
          listener: (context, state) {
            if (state is ShiftUnauthorized) {
              _handleSessionExpired(state.message);
            } else if (state is ShiftLoaded) {
              setState(() => _cachedShifts = state.result);
            }
          },
        ),
        BlocListener<AdhocBloc, AdhocState>(
          listener: (context, state) {
            if (state is AdhocUnauthorized) {
              _handleSessionExpired(state.message);
            } else if (state is AdhocSubmitSuccess) {
              _showSuccessDialog(state.message);
            } else if (state is AdhocSubmitError) {
              _showErrorDialog(state.message);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _green),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Add ADHOC Request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _green,
              fontFamily: 'Manrope',
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adhoc Transport Scheduling',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003D27),
                  fontFamily: 'Manrope',
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Complete the form below to request special transport arrangements outside of standard shift patterns.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF596064),
                  fontFamily: 'Manrope',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // ── Schedule Date ─────────────────────────────────────────────
              _buildFieldLabel('SCHEDULE DATE'),
              const SizedBox(height: 8),
              _buildDateField(),
              const SizedBox(height: 20),

              // ── Office Location ───────────────────────────────────────────
              _buildFieldLabel('OFFICE LOCATION'),
              const SizedBox(height: 8),
              _buildOfficeLocationSection(),
              const SizedBox(height: 20),

              // ── Trip Type ─────────────────────────────────────────────────
              _buildFieldLabel('TRIP TYPE'),
              const SizedBox(height: 8),
              _buildTripTypeToggle(),
              const SizedBox(height: 20),

              // ── Shift ─────────────────────────────────────────────────────
              _buildFieldLabel('SHIFT'),
              const SizedBox(height: 8),
              _buildShiftSection(),
              const SizedBox(height: 20),

              // ── Select Members ────────────────────────────────────────────
              _buildMembersSection(),
              const SizedBox(height: 20),

              // ── Remarks ───────────────────────────────────────────────────
              _buildFieldLabel('REMARKS'),
              const SizedBox(height: 8),
              _buildRemarksField(),
              const SizedBox(height: 32),

              _buildSubmitButton(enabled: _selectedMemberIndices.isNotEmpty),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _labelColor,
        letterSpacing: 0.9,
        fontFamily: 'Manrope',
      ),
    );
  }

  // ── Schedule Date (calendar picker like trip_detail.dart) ─────────────────

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () async {
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        final picked = await showDatePicker(
          context: context,
          initialDate: _scheduleDate.isBefore(today) ? today : _scheduleDate,
          firstDate: today,
          lastDate: DateTime(today.year + 1, 12, 31),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _green,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _scheduleDate = picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: _green, size: 18),
            const SizedBox(width: 10),
            Text(
              _formatDisplayDate(_scheduleDate),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A3C2B),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Office Location dropdown ──────────────────────────────────────────────

  Widget _buildOfficeLocationSection() {
    return BlocBuilder<RosterBloc, RosterState>(
      builder: (context, state) {
        if (state is RosterInitial || state is RosterLoading) {
          return _buildLoadingDropdown();
        }
        if (state is RosterError) {
          return _buildRetryTile(
            state.message,
            onRetry: () => context
                .read<RosterBloc>()
                .add(const FetchRosterUserDetails()),
          );
        }
        if (state is RosterLoaded) {
          final locations = state.details.locations;
          if (locations.isEmpty) {
            return _buildInfoTile('No offices available');
          }
          final idx = _selectedLocationIndex.clamp(0, locations.length - 1);
          return _buildDropdown(
            value: locations[idx].locName,
            items: locations.map((l) => l.locName).toList(),
            onChanged: (val) {
              if (val == null) return;
              final i = locations.indexWhere((l) => l.locName == val);
              if (i >= 0) _onLocationSelected(i, locations);
            },
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ── Trip Type toggle ──────────────────────────────────────────────────────

  Widget _buildTripTypeToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleOption(
            label: 'Log In',
            selected: _isLogin,
            onTap: () {
              if (!_isLogin) {
                setState(() {
                  _isLogin = true;
                  _selectedPickShift = null;
                  _selectedDropShift = null;
                });
              }
            },
          ),
          _buildToggleOption(
            label: 'Logout',
            selected: !_isLogin,
            onTap: () {
              if (_isLogin) {
                setState(() {
                  _isLogin = false;
                  _selectedPickShift = null;
                  _selectedDropShift = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? _green : const Color(0xFF596064),
              fontFamily: 'Manrope',
            ),
          ),
        ),
      ),
    );
  }

  // ── Shift dropdown ────────────────────────────────────────────────────────

  Widget _buildShiftSection() {
    return BlocBuilder<ShiftBloc, ShiftState>(
      builder: (context, state) {
        if (_cachedShifts == null) {
          if (state is ShiftInitial || state is ShiftLoading) {
            return _buildLoadingDropdown();
          }
          if (state is ShiftError) {
            return _buildRetryTile(
              state.message,
              onRetry: () {
                final rosterState = context.read<RosterBloc>().state;
                if (rosterState is RosterLoaded) {
                  final locations = rosterState.details.locations;
                  if (locations.isNotEmpty) {
                    final idx = _selectedLocationIndex.clamp(0, locations.length - 1);
                    context.read<ShiftBloc>().add(
                          FetchShifts(
                            locCode: locations[idx].locCode,
                            empId: rosterState.details.empId,
                          ),
                        );
                  }
                }
              },
            );
          }
          return _buildInfoTile('Select an office to load shifts');
        }

        final cached = _cachedShifts!;
        if (_isLogin) {
          if (cached.pickShifts.isEmpty) return _buildInfoTile('No shifts available');
          final uniquePickShifts = _deduplicateByTime(cached.pickShifts.map((s) => (s.shiftId, s.shiftTime)).toList());
          final selectedTime = _selectedPickShift?.shiftTime ?? uniquePickShifts.first.$2;
          final safeTime = uniquePickShifts.any((s) => s.$2 == selectedTime) ? selectedTime : uniquePickShifts.first.$2;
          return _buildDropdown(
            value: safeTime,
            items: uniquePickShifts.map((s) => s.$2).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedPickShift = cached.pickShifts.firstWhere((s) => s.shiftTime == val);
              });
            },
          );
        } else {
          if (cached.dropShifts.isEmpty) return _buildInfoTile('No shifts available');
          final uniqueDropShifts = _deduplicateByTime(cached.dropShifts.map((s) => (s.shiftId, s.shiftTime)).toList());
          final selectedTime = _selectedDropShift?.shiftTime ?? uniqueDropShifts.first.$2;
          final safeTime = uniqueDropShifts.any((s) => s.$2 == selectedTime) ? selectedTime : uniqueDropShifts.first.$2;
          return _buildDropdown(
            value: safeTime,
            items: uniqueDropShifts.map((s) => s.$2).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedDropShift = cached.dropShifts.firstWhere((s) => s.shiftTime == val);
              });
            },
          );
        }
      },
    );
  }

  // ── Members section (drList like team_cab) ────────────────────────────────

  Widget _buildMembersSection() {
    return BlocBuilder<RosterBloc, RosterState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFieldLabel('SELECT MEMBERS'),
              const SizedBox(height: 12),
              if (state is RosterInitial || state is RosterLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: _green),
                  ),
                )
              else if (state is RosterError)
                _buildRetryTile(
                  state.message,
                  onRetry: () => context
                      .read<RosterBloc>()
                      .add(const FetchRosterUserDetails()),
                )
              else if (state is RosterLoaded) ...[
                if (state.details.drList.isEmpty)
                  _buildInfoTile('No team members found')
                else
                  ...List.generate(state.details.drList.length, (i) {
                    final member = state.details.drList[i];
                    final isSelected = _selectedMemberIndices.contains(i);
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i < state.details.drList.length - 1 ? 10 : 0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedMemberIndices.remove(i);
                            } else {
                              _selectedMemberIndices.add(i);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? _green : const Color(0xFFE5EDE9),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _lightGreen
                                      : const Color(0xFFF0F5F2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: isSelected ? _green : const Color(0xFF7A9A8A),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.empName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A3C2B),
                                        fontFamily: 'Manrope',
                                      ),
                                    ),
                                    Text(
                                      'ID: ${member.empId}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF596064),
                                        fontFamily: 'Manrope',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1A3C6B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1A3C6B)
                                        : const Color(0xFFBDBDBD),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Remarks ───────────────────────────────────────────────────────────────

  Widget _buildRemarksField() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _remarksController,
        maxLines: 4,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A3C2B),
          fontFamily: 'Manrope',
        ),
        decoration: const InputDecoration(
          hintText: 'Enter additional details or instructions...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: Color(0xFF9AA0A6),
            fontFamily: 'Manrope',
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Widget _buildSubmitButton({required bool enabled}) {
    return BlocBuilder<AdhocBloc, AdhocState>(
      builder: (context, state) {
        final isLoading = state is AdhocSubmitting;
        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading || !enabled ? null : _onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Manrope',
                    ),
                  ),
          ),
        );
      },
    );
  }

  void _onSubmit() {
    final rosterState = context.read<RosterBloc>().state;
    if (rosterState is! RosterLoaded) {
      _showSnack('Office data is still loading. Please wait.');
      return;
    }

    final locations = rosterState.details.locations;
    if (locations.isEmpty) {
      _showSnack('No office location available.');
      return;
    }

    final locIdx = _selectedLocationIndex.clamp(0, locations.length - 1);
    final selectedLocation = locations[locIdx];

    if (_cachedShifts == null) {
      _showSnack('Shifts are still loading. Please wait.');
      return;
    }

    final int shiftId;
    if (_isLogin) {
      final shift = _selectedPickShift ?? _cachedShifts!.pickShifts.firstOrNull;
      if (shift == null) {
        _showSnack('Please select a shift.');
        return;
      }
      shiftId = shift.shiftId;
    } else {
      final shift = _selectedDropShift ?? _cachedShifts!.dropShifts.firstOrNull;
      if (shift == null) {
        _showSnack('Please select a shift.');
        return;
      }
      shiftId = shift.shiftId;
    }

    final reqBy = rosterState.details.empId;
    final reqFor = _selectedMemberIndices.isNotEmpty
        ? _selectedMemberIndices
            .map((i) => rosterState.details.drList[i].empId.toString())
            .join(',')
        : rosterState.details.empId.toString();

    context.read<AdhocBloc>().add(
          SubmitAdhocRequest(
            locCode: selectedLocation.locCode,
            tripDate: _formatApiDate(_scheduleDate),
            tripType: _isLogin ? 1 : 2,
            shiftId: shiftId,
            reqBy: reqBy,
            reqFor: reqFor,
            remarks: _remarksController.text.trim(),
          ),
        );
  }

  void _showSuccessDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: _green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Request Submitted',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Manrope',
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty
                  ? message
                  : 'Your ADHOC request has been submitted successfully.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF596064),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFB40D1A), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Submission Failed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Manrope',
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty ? message : 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF596064),
                fontFamily: 'Manrope',
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB40D1A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Manrope',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  List<(int, String)> _deduplicateByTime(List<(int, String)> shifts) {
    final seen = <String>{};
    return shifts.where((s) => seen.add(s.$2)).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF596064), size: 22),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A3C2B),
            fontFamily: 'Manrope',
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _green),
          ),
          SizedBox(width: 12),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9AA0A6),
              fontFamily: 'Manrope',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryTile(String message, {required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF596064)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: _green, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Color(0xFF596064)),
      ),
    );
  }
}

