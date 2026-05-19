import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_details_roaster_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'commute_timing.dart';

class SelectOfficeScreen extends StatelessWidget {
  final bool isLogIn;
  final String fromDate;
  final String toDate;
  final String weekOffs;

  const SelectOfficeScreen({
    super.key,
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RosterBloc>()..add(const FetchRosterUserDetails()),
      child: _SelectOfficeView(
        isLogIn: isLogIn,
        fromDate: fromDate,
        toDate: toDate,
        weekOffs: weekOffs,
      ),
    );
  }
}

class _SelectOfficeView extends StatefulWidget {
  final bool isLogIn;
  final String fromDate;
  final String toDate;
  final String weekOffs;

  const _SelectOfficeView({
    required this.isLogIn,
    required this.fromDate,
    required this.toDate,
    required this.weekOffs,
  });

  @override
  State<_SelectOfficeView> createState() => _SelectOfficeViewState();
}

class _SelectOfficeViewState extends State<_SelectOfficeView> {
  int _selectedIndex = 0;

  static const int _totalSteps = 4;
  static const int _completedSteps = 2;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF1B5E42),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Office',
                    style: TextStyle(
                      color: Color(0xFF1B5E42),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(_totalSteps, (index) {
                  final isActive = index < _completedSteps;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                          right: index < _totalSteps - 1 ? 6 : 0),
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF1B5E42)
                            : const Color(0xFFD6E8DF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 28),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Available Branches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: BlocConsumer<RosterBloc, RosterState>(
                listener: (context, state) {
                  if (state is RosterUnauthorized) {
                    _handleSessionExpired(state.message);
                  }
                },
                builder: (context, state) {
                  if (state is RosterLoading || state is RosterInitial) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1B5E42),
                      ),
                    );
                  }

                  if (state is RosterUnauthorized) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline,
                                color: Color(0xFF1B5E42), size: 40),
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

                  if (state is RosterError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFF1B5E42), size: 40),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF7A9A8A), fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context
                                .read<RosterBloc>()
                                .add(const FetchRosterUserDetails()),
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: Color(0xFF1B5E42)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is RosterLoaded) {
                    final locations = state.details.locations;

                    if (locations.isEmpty) {
                      return const Center(
                        child: Text(
                          'No offices available',
                          style: TextStyle(
                              color: Color(0xFF7A9A8A), fontSize: 14),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: locations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final location = locations[index];
                        final isSelected = _selectedIndex == index;
                        return _OfficeTile(
                          location: location,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => _selectedIndex = index),
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final state = context.read<RosterBloc>().state;
                    if (state is! RosterLoaded) return;
                    debugPrint(
                      '[SELECT_OFFICE] Next tapped → '
                      'locCode=${state.details.locCode} '
                      'empId=${state.details.empId} '
                      'isLogIn=${widget.isLogIn} '
                      'fromDate=${widget.fromDate} '
                      'toDate=${widget.toDate} '
                      'weekOffs="${widget.weekOffs}"',
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommuteTimingScreen(
                          locCode: state.details.locCode,
                          empId: state.details.empId,
                          isLogIn: widget.isLogIn,
                          fromDate: widget.fromDate,
                          toDate: widget.toDate,
                          weekOffs: widget.weekOffs,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E42),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfficeTile extends StatelessWidget {
  final LocationModel location;
  final bool isSelected;
  final VoidCallback onTap;

  const _OfficeTile({
    required this.location,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B5E42)
                : const Color(0xFFE5EDE9),
            width: isSelected ? 1.5 : 1.0,
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
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.domain,
                color: Color(0xFF1B5E42),
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                location.locName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B5E42),
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(width: 12),

            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1B5E42)
                      : const Color(0xFFBBCFC6),
                  width: isSelected ? 2 : 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1B5E42),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
