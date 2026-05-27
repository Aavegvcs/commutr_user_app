import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_bloc.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_event.dart';
import 'package:commutr_main/features/trip_detail/bloc/roaster_state.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_details_roaster_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectEmployeeScreen extends StatelessWidget {
  const SelectEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<RosterBloc>(),
      child: const _SelectEmployeeView(),
    );
  }
}

class _SelectEmployeeView extends StatefulWidget {
  const _SelectEmployeeView();

  @override
  State<_SelectEmployeeView> createState() => _SelectEmployeeViewState();
}

class _SelectEmployeeViewState extends State<_SelectEmployeeView> {
  int _selectedIndex = -1;

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
                    'Select Employee',
                    style: TextStyle(
                      color: Color(0xFF1B5E42),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Employee List',
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
                    final employees = state.details.drList;

                    if (employees.isEmpty) {
                      return const Center(
                        child: Text(
                          'No employees available',
                          style: TextStyle(
                              color: Color(0xFF7A9A8A), fontSize: 14),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: employees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final isSelected = _selectedIndex == index;
                        return _EmployeeTile(
                          employee: employee,
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
                child: BlocBuilder<RosterBloc, RosterState>(
                  builder: (context, state) {
                    final loaded = state is RosterLoaded &&
                        state.details.drList.isNotEmpty &&
                        _selectedIndex >= 0;
                    return ElevatedButton(
                      onPressed: loaded
                          ? () {
                              final employees =
                                  state.details.drList;
                              final selected = employees[_selectedIndex];
                              Navigator.pop(context, selected);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E42),
                        disabledBackgroundColor:
                            const Color(0xFF1B5E42).withValues(alpha: 0.4),
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
                      child: const Text('Confirm'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final DrModel employee;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmployeeTile({
    required this.employee,
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
                Icons.person,
                color: Color(0xFF1B5E42),
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.empName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B5E42),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: ${employee.empId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A9A8A),
                    ),
                  ),
                ],
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
