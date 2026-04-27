import 'dart:math' show pi;

import 'package:commutr_main/ride_tracking/ride_tracking.dart';
import 'package:commutr_main/trip_detail/presentation/screen/trip_detail.dart';
import 'package:flutter/material.dart';

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  int _selectedIndex = 0;
  bool _loginExpanded = false;
  bool _logoutExpanded = false;

  void _showCancelRideDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => const CancelRideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    double fabSize = 100.0;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      drawer: const AppDrawer(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0.0, -15.0),
        child: SizedBox(
          width: fabSize,
          height: fabSize,
          child: Image.asset(
            'assets/images/welcome_add.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMainContent()),
            ],
          ),

          // Bottom navigation bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Container(
                //   width: double.infinity,
                //   height: 45,
                //   color: Color(0xFFF9F9F9),
                // ),
                _buildBottomNav(),
              ],
            ),
          ),

          // SOS button
          Positioned(
            bottom: 90,
            left: 16,
            child: _buildSOSButton(),
          ),

          // FAB image (sits above the notch)
          // Positioned(
          //   bottom: 28,
          //   left: 0,
          //   right: 0,
          //   child: Center(child: _buildFAB()),
          // ),

          // // Left lc.png decoration
          // Positioned(
          //   bottom: 65,
          //   left: MediaQuery.of(context).size.width * 0.322,
          //   child: Center(
          //     child: Image.asset(
          //       'assets/images/lc.png',
          //       width: 24,
          //       height: 24,
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          //
          // // Right lc.png decoration (flipped)
          // Positioned(
          //   bottom: 65,
          //   right: MediaQuery.of(context).size.width * 0.322,
          //   child: Transform(
          //     alignment: Alignment.center,
          //     transform: Matrix4.rotationY(3.1416),
          //     child: Center(
          //       child: Image.asset(
          //         'assets/images/lc.png',
          //         width: 24,
          //         height: 24,
          //         fit: BoxFit.cover,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildSchedulesSection();
      case 1:
        return _buildTripHistorySection();
      default:
        return _buildSchedulesSection();
    }
  }

  Widget _buildTripHistorySection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Trip History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'No trips recorded yet.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 150,
      child: Stack(
        children: [
          Image.asset(
            'assets/images/welcome_header.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.menu, color: Colors.white, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'HELLO,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Text(
                          'Mr. Yash',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.notification_add_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Schedules',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '9th Mar, Monday',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  'Today',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildScheduleCard(
            type: 'login',
            label: 'Login',
            time: '2:03 AM',
            isExpanded: _loginExpanded,
            onTap: () => setState(() => _loginExpanded = !_loginExpanded),
          ),
          const SizedBox(height: 10),
          _buildScheduleCard(
            type: 'logout',
            label: 'Logout',
            time: '2:03 AM',
            isExpanded: _logoutExpanded,
            onTap: () => setState(() => _logoutExpanded = !_logoutExpanded),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required String type,
    required String label,
    required String time,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final bool isLogin = type == 'login';
    final Color accentColor =
    isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final Color statusColor =
    isLogin ? const Color(0xFFE0A309) : const Color(0xFFB40D1A);
    final Color tagBgColor =
    isLogin ? const Color(0xFFE8F5EE) : const Color(0xFFFFF0EE);
    final Color tagTextColor =
    isLogin ? const Color(0xFF3E9B73) : const Color(0xFFB40D1A);
    final IconData arrowIcon = isLogin ? Icons.login : Icons.logout;
    final List<String> otpDigits = ['3', '3', '3', '3'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              splashColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  Icon(arrowIcon, color: accentColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tagTextColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tagBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tagTextColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xff596064),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              splashColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Icon(Icons.check_circle_outline, size: 13, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    'Vehicle Allocated',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'TRIP DETAIL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff596064),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/pre_location.png',
                          width: 19,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Shastri Nagar, Phase 2',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3437),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Main Entrance Gate, Pune',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff596064),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DLF Gurugram',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3437),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Main Entrance Gate, Pune',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff596064),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Planned Pickup',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xff6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '06:42 AM',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Info.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xff6B7280),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'HR-55-AW-0640',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boarding OTP',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xff6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: otpDigits
                          .map(
                            (digit) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F3ED),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            digit,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF002D1C),
                            ),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  InkWell(
                    splashColor: Colors.transparent,
                    onTap: (){
                      _showCancelRideDialog(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x33BA1A1A)),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFBA1A1A),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    splashColor: Colors.transparent,
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TripDetailsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RideTrackingScreen(),
                          ),
                        );
                      },
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: tagBgColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location, size: 16, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              'Track Vehicle',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFFE8E8E8)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Boarding OTP',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF282828),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: otpDigits
                                .map(
                                  (digit) => Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 23,
                                height: 23,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6F3ED),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  digit,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF002D1C),
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0.0, 10.0),
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: tagBgColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.my_location,
                                  size: 16, color: accentColor),
                              const SizedBox(width: 6),
                              Text(
                                'Track Vehicle',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: () {},
      child: Image.asset(
        'assets/images/sos.png',
        width: 67,
        height: 67,
        fit: BoxFit.cover,
      ),
    );
  }

  // Widget _buildFAB() {
  //   const fabSize = 100.0;
  //   return GestureDetector(
  //     onTap: () {},
  //     child: SizedBox(
  //       width: fabSize,
  //       height: fabSize,
  //       child: Image.asset(
  //         'assets/images/welcome_add.png',
  //         fit: BoxFit.cover,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildBottomNav() {
    // The FAB image is 115px tall, positioned bottom: 28
    // So it overlaps the nav bar by roughly: 115 - 28 = 87px from bottom
    // Nav bar height is 86, so the notch needs to accommodate ~57px wide circle
    return CustomPaint(
      painter: _BottomNavNotchPainter(),
      child: SizedBox(
        height: 86,
        child: Row(
          children: [
            // Home tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 0
                            ? const Color(0xFFCCE8D8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.home_rounded,
                            color: _selectedIndex == 0
                                ? const Color(0xFF1A6B3C)
                                : const Color(0xFF9E9E9E),
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Home',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedIndex == 0
                                  ? const Color(0xFF1A6B3C)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center gap for notch
            const SizedBox(width: 120),

            // Trip History tab
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedIndex == 1
                            ? const Color(0xFFCCE8D8)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_bus_rounded,
                            color: _selectedIndex == 1
                                ? const Color(0xFF1A6B3C)
                                : const Color(0xFF9E9E9E),
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Trip History',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedIndex == 1
                                  ? const Color(0xFF1A6B3C)
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Draws the white nav bar with a smooth circular notch cut out at the top-center
class _BottomNavNotchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    const notchRadius = 0.0; // matches the FAB image circle area
    const notchMargin = 0.0;
    final centerX = size.width / 2;
    const totalRadius = notchRadius + notchMargin;

    final path = Path();
    path.moveTo(0, 0);

    // Left straight → left curve start
    path.lineTo(centerX - totalRadius - 12, 0);

    // Smooth left entry curve
    path.quadraticBezierTo(
      centerX - totalRadius,
      0,
      centerX - totalRadius + 4,
      8,
    );

    // Arc across the notch (bottom half of circle = dips down)
    path.arcToPoint(
      Offset(centerX + totalRadius - 4, 8),
      radius: const Radius.circular(totalRadius),
      clockwise: false,
    );

    // Smooth right exit curve
    path.quadraticBezierTo(
      centerX + totalRadius,
      0,
      centerX + totalRadius + 12,
      0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw shadow first, then white bar
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, paint);

    // Top border line (skipping the notch area)
    final borderPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final borderPath = Path();
    borderPath.moveTo(0, 0.5);
    borderPath.lineTo(centerX - totalRadius - 12, 0.5);
    borderPath.moveTo(centerX + totalRadius + 12, 0.5);
    borderPath.lineTo(size.width, 0.5);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LowerSemicircleBorderPainter extends CustomPainter {
  _LowerSemicircleBorderPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, (size.height / 2) + 10);
    final radius = size.shortestSide / 2.3 - strokeWidth / 2.3;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LowerSemicircleBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}


class CancelRideDialog extends StatelessWidget {
  const CancelRideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning icon circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Color(0xFFFFF0EE),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xffBA1A1A),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Cancel this ride?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xff181C1B),
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle
            const Text(
              'Are you sure you want to cancel your trip? You might be charged a cancellation fee.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Buttons row
            Row(
              children: [
                // Cancel Ride button (outlined, red text)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCC2222),
                      side: const BorderSide(
                        color: Color(0xFFFFCCCC),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Handle cancel ride
                    },
                    child: const Text(
                      'Cancel Ride',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Keep Ride button (filled, dark green)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5C38),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Handle keep ride
                    },
                    child: const Text(
                      'Keep Ride',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 310,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              _DrawerHeader(),

              const Divider(height: 1, color: Color(0xFFE0E0E0)),

              // ── Environmental Impact Card ────────────────────────────
              _EnvironmentalCard(),

              const SizedBox(height: 8),

              // ── MY SCHEDULE section ──────────────────────────────────
              _SectionLabel('MY SCHEDULE'),
              _DrawerItem(
                icon: Icons.calendar_today_outlined,
                label: 'Create Schedule',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.calendar_month_outlined,
                label: 'Weekly Offs',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.history,
                label: 'Trip History',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.people_outline,
                label: 'Team Cab',
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── MY ACCOUNT section ───────────────────────────────────
              _SectionLabel('MY ACCOUNT'),
              _DrawerItem(
                icon: Icons.home_outlined,
                label: 'Request Address Change',
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── SAFETY section ───────────────────────────────────────
              _SectionLabel('SAFETY'),
              _DrawerItem(
                icon: Icons.shield_outlined,
                label: 'Women Safety',
                onTap: () => Navigator.pop(context),
                iconColor: const Color(0xFFE53935),
                iconBgColor: const Color(0xFFFCECEC),
              ),

              const SizedBox(height: 4),

              // ── SUPPORT section ──────────────────────────────────────
              _SectionLabel('SUPPORT'),
              _DrawerItem(
                icon: Icons.headset_mic_outlined,
                label: 'Call Help Desk',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.directions_bus_outlined,
                label: 'Contact Travel Desk',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.quiz_outlined,
                label: "FAQ's",
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 4),

              // ── APP section ──────────────────────────────────────────
              _SectionLabel('APP'),
              _DrawerItem(
                icon: Icons.feedback_outlined,
                label: 'App Feedback',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerItem(
                icon: Icons.star_outline,
                label: 'Rate This App',
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header Widget ────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8F5F0),
              border: Border.all(color: const Color(0xFF8DCFB8), width: 2),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF8DCFB8),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Rahul Kumar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'EMP ID: 450921',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
                Text(
                  'Office : D21',
                  style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                ),
              ],
            ),
          ),
          // Close / back icon
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF555555)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── Environmental Impact Card ────────────────────────────────────────────────

class _EnvironmentalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A7A5E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ENVIRONMENTAL IMPACT',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '18.4 ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'kg carbon saved',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF27A87A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 18, top: 14, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── Drawer Menu Item ─────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBgColor;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = const Color(0xFF1A7A5E),
    this.iconBgColor = const Color(0xFFE8F5F0),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: const Color(0xFFE8F5F0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              // Chevron
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFBBBBBB),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}