import 'package:flutter/material.dart';

class WeeklyOffScreen extends StatefulWidget {
  const WeeklyOffScreen({super.key});

  @override
  State<WeeklyOffScreen> createState() => _WeeklyOffScreenState();
}

class _WeeklyOffScreenState extends State<WeeklyOffScreen> {
  static const Color primaryGreen = Color(0xFF1A3C2E);
  static const int minSelection = 1;
  static const int maxSelection = 6;

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  final Set<String> _selectedDays = {'MON', 'FRI'};

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        // Don't deselect if it would go below minimum
        if (_selectedDays.length > minSelection) {
          _selectedDays.remove(day);
        } else {
          _showSnackBar('You must select at least $minSelection day');
        }
      } else {
        // Don't select if it would exceed maximum
        if (_selectedDays.length < maxSelection) {
          _selectedDays.add(day);
        } else {
          _showSnackBar('You can select at most $maxSelection days');
        }
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _savePreferences() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved: ${_selectedDays.join(', ')}'),
        duration: const Duration(seconds: 2),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
                    onToggle: _toggleDay,
                    primaryGreen: primaryGreen,
                  ),
                ],
              ),
            ),
          ),
          _SaveButton(
            onPressed: _savePreferences,
            primaryGreen: primaryGreen,
          ),
        ],
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
      itemCount: 9, // 7 days + 2 empty slots
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
            SizedBox(height: 16,),
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
            SizedBox(height: 16,),

          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color primaryGreen;

  const _SaveButton({required this.onPressed, required this.primaryGreen});

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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
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