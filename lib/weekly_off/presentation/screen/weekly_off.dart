import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/welcome/presentation/screen/welcome.dart';
import '../../bloc/weekly_off_bloc.dart';
import '../../bloc/weekly_off_event.dart';
import '../../bloc/weekly_off_state.dart';

class WeeklyOffScreen extends StatelessWidget {
  const WeeklyOffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WeeklyOffBloc>(),
      child: const _WeeklyOffView(),
    );
  }
}

class _WeeklyOffView extends StatefulWidget {
  const _WeeklyOffView();

  @override
  State<_WeeklyOffView> createState() => _WeeklyOffViewState();
}

class _WeeklyOffViewState extends State<_WeeklyOffView> {
  static const Color primaryGreen = Color(0xFF1A3C2E);
  static const int minSelection = 1;
  static const int maxSelection = 6;

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  /// Filled after [LoadWeeklyOffEvent]; until then UI shows loading.
  final Set<String> _selectedDays = {};

  /// True once the initial load (success or failure) has settled, so the UI
  /// can be interacted with even when no days are selected.
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    context.read<WeeklyOffBloc>().add(LoadWeeklyOffEvent());
  }

  /// Maps API `weekOff` (e.g. `MON,FRI`) to grid tokens in calendar order.
  /// Returns an empty set when the API provides no value (no defaults).
  Set<String> _selectionFromWeekOff(String? weekOff) {
    final raw = weekOff?.trim();
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final tokens = raw
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    final ordered = <String>[];
    for (final d in _days) {
      if (tokens.contains(d)) ordered.add(d);
    }
    if (ordered.isEmpty) return {''};
    if (ordered.length > maxSelection) {
      return ordered.take(maxSelection).toSet();
    }
    return ordered.toSet();
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > minSelection) {
          _selectedDays.remove(day);
        } else {
          _showSnackBar('You must select at least $minSelection day');
        }
      } else {
        if (_selectedDays.length < maxSelection) {
          _selectedDays.add(day);
        } else {
          _showSnackBar('You can select at most $maxSelection days');
        }
      }
    });
  }

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: color ?? primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showResultDialog({required bool success, required String message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (success ? primaryGreen : Colors.red)
                    .withValues(alpha: 0.1),
              ),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? primaryGreen : Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Success' : 'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: success ? primaryGreen : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF616161)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (success) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const Welcome()),
                      (route) => false,
                    );
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? primaryGreen : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _savePreferences() {
    context.read<WeeklyOffBloc>().add(
          UpdateWeeklyOffEvent(weekOff: _selectedDays.join(',')),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WeeklyOffBloc, WeeklyOffState>(
      listener: (context, state) {
        if (state is WeeklyOffLoaded) {
          final row = state.response.result?.isNotEmpty == true
              ? state.response.result!.first
              : null;
          if (!mounted) return;
          setState(() {
            _loaded = true;
            _selectedDays
              ..clear()
              ..addAll(_selectionFromWeekOff(row?.weekOff));
          });
        } else if (state is WeeklyOffSaved) {
          final dbResponse = state.response.result?.isNotEmpty == true
              ? state.response.result!.first.dBResponse
              : null;
          _showResultDialog(
            success: true,
            message: dbResponse?.trim().isNotEmpty == true
                ? dbResponse!
                : (state.response.message ?? 'Preferences saved!'),
          );
        } else if (state is WeeklyOffFailure) {
          if (!mounted) return;
          setState(() {
            _loaded = true;
          });
          _showResultDialog(success: false, message: state.message);
        }
      },
      child: BlocBuilder<WeeklyOffBloc, WeeklyOffState>(
        builder: (context, state) {
          final isLoading = state is WeeklyOffLoading;
          // Interaction is gated on load completion, not on having a
          // selection, so a user with no weekly-off can still pick days.
          final canInteract = _loaded && !isLoading;
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: const Color(0xFFF0F0F0),
              elevation: 0,
              leading: const BackButton(color: primaryGreen),
              title: const Text(
                'Weekly Off',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
              titleSpacing: 0,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'When are you taking a\nbreak?',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _DayGrid(
                          days: _days,
                          selectedDays: _selectedDays,
                          onToggle: canInteract ? _toggleDay : (_) {},
                          primaryGreen: primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ),
                _SaveButton(
                  onPressed: canInteract ? _savePreferences : null,
                  isLoading: isLoading,
                  primaryGreen: primaryGreen,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DayGrid extends StatelessWidget {
  final List<String> days;
  final Set<String> selectedDays;
  final void Function(String) onToggle;
  final Color primaryGreen;

  const _DayGrid({
    required this.days,
    required this.selectedDays,
    required this.onToggle,
    required this.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.93,
      ),
      itemCount: 7, // 7 days + 2 empty slots
      itemBuilder: (context, index) {
        if (index < days.length) {
          final day = days[index];
          final isSelected = selectedDays.contains(day);
          return _DayCard(
            day: day,
            isSelected: isSelected,
            onTap: () => onToggle(day),
            primaryGreen: primaryGreen,
          );
        }
        // Empty placeholder cells
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  final String day;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryGreen;

  const _DayCard({
    required this.day,
    required this.isSelected,
    required this.onTap,
    required this.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 16,
            ),
            Text(
              day,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? primaryGreen : const Color(0xFF9E9E9E),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryGreen : const Color(0xFFBDBDBD),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              height: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color primaryGreen;

  const _SaveButton({
    required this.onPressed,
    required this.isLoading,
    required this.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Save Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.done_all, size: 20),
                ],
              ),
      ),
    );
  }
}
