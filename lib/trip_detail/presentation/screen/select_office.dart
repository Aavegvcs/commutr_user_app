import 'package:commutr_main/trip_detail/presentation/screen/commute_timing.dart';
import 'package:flutter/material.dart';

class OfficeModel {
  final String name;
  final String address;

  const OfficeModel({required this.name, required this.address});
}

class SelectOfficeScreen extends StatefulWidget {
  const SelectOfficeScreen({super.key});

  @override
  State<SelectOfficeScreen> createState() => _SelectOfficeScreenState();
}

class _SelectOfficeScreenState extends State<SelectOfficeScreen> {
  int _selectedIndex = 0;

  final List<OfficeModel> _offices = const [
    OfficeModel(
      name: 'Main Technology Hub\nBengaluru',
      address: 'BKC Heights, Suite 102',
    ),
    OfficeModel(
      name: 'FinTech Center -\nMumbai',
      address: 'BKC Heights, Suite 102',
    ),
    OfficeModel(
      name: 'Innovation Lab -\nDelhi',
      address: 'Vasant Square, Block A',
    ),
  ];

  // Progress step indicator (4 steps, 2 active)
  static const int _totalSteps = 4;
  static const int _completedSteps = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with back arrow and title
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

            // Step progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(_totalSteps, (index) {
                  final isActive = index < _completedSteps;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 6 : 0),
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

            // Section label
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

            // Office cards list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _offices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final office = _offices[index];
                  final isSelected = _selectedIndex == index;
                  return _OfficeTile(
                    office: office,
                    isSelected: isSelected,
                    onTap: () => setState(() => _selectedIndex = index),
                  );
                },
              ),
            ),

            // Bottom Next button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommuteTimingScreen(),
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
  final OfficeModel office;
  final bool isSelected;
  final VoidCallback onTap;

  const _OfficeTile({
    required this.office,
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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Building icon container
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

            // Name and address
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    office.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B5E42),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    office.address,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A9A8A),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Radio button
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