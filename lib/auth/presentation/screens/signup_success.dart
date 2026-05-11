import 'dart:math' as math;
import 'package:commutr_main/auth/presentation/screens/mobile_no_verification.dart';
import 'package:flutter/material.dart';

class SignupSuccessScreen extends StatefulWidget {
  const SignupSuccessScreen({super.key});

  @override
  State<SignupSuccessScreen> createState() => _SignupSuccessScreenState();
}

class _SignupSuccessScreenState extends State<SignupSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _pulseController;
  late AnimationController _countdownController;
  late Animation<double> _checkAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _countdownAnimation;

  int _secondsRemaining = 5;

  static const Color _darkGreen = Color(0xFF1A4A3A);
  static const Color _mediumGreen = Color(0xFF2D6A52);
  static const Color _lightGreenBg = Color(0xFFEAF5F0);
  static const Color _accentGreen = Color(0xFF4CAF85);
  static const Color _glowGreen = Color(0xFF80D4B0);

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _countdownAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.linear),
    );

    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = _secondsRemaining; i > 0; i--) {
      if (!mounted) return;
      setState(() => _secondsRemaining = i);
      _countdownController.reset();
      await _countdownController.forward();
    }
    if (mounted) {
      setState(() => _secondsRemaining = 0);
      if (_secondsRemaining == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MobileNoVerification(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _pulseController.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MobileNoVerification(),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: _lightGreenBg,
        body: Stack(
          children: [
            // Background wave decoration
            Positioned.fill(
              child: CustomPaint(painter: _WavePainter()),
            ),
            SafeArea(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0),
                    child: LayoutBuilder(builder: (context, constraints) {
                      return SingleChildScrollView(
                          child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(flex: 2),

                              // Animated Check Icon
                              ScaleTransition(
                                scale: _checkAnimation,
                                child: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      width: 110,
                                      height: 110,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _glowGreen.withOpacity(
                                              0.5 * _pulseAnimation.value,
                                            ),
                                            blurRadius:
                                                40 * _pulseAnimation.value,
                                            spreadRadius:
                                                10 * _pulseAnimation.value,
                                          ),
                                        ],
                                      ),
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [_mediumGreen, _darkGreen],
                                      ),
                                      border: Border.all(
                                        color: _glowGreen.withOpacity(0.6),
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 52,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Title
                              const Text(
                                'Your details have been\nsubmitted',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0D2B20),
                                  height: 1.25,
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Subtitle
                              Text(
                                'Your account verification is now in\nprogress. We\'ll verify your details shortly.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black.withOpacity(0.55),
                                  height: 1.55,
                                ),
                              ),

                              const Spacer(flex: 2),

                              // Redirect countdown box
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.08),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Redirecting to Login...',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black.withOpacity(0.65),
                                      ),
                                    ),
                                    // Countdown circle
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _countdownAnimation,
                                            builder: (context, _) {
                                              return CustomPaint(
                                                size: const Size(40, 40),
                                                painter: _CountdownRingPainter(
                                                  progress:
                                                      _countdownAnimation.value,
                                                  color: _accentGreen,
                                                ),
                                              );
                                            },
                                          ),
                                          Text(
                                            '$_secondsRemaining',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2D6A52),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Go Back to Login button
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _darkGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                  ),
                                  child: const Text(
                                    'Go Back to Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ));
                    })))
          ],
        ),
      ),
    );
  }
}

// Countdown ring painter
class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CountdownRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background ring
    final bgPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress || old.color != color;
}

// Subtle wavy background decoration
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF85).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 4; i++) {
      final path = Path();
      final offsetY = size.height * 0.55 + i * 60.0;
      path.moveTo(0, offsetY);
      path.cubicTo(
        size.width * 0.25,
        offsetY - 40,
        size.width * 0.75,
        offsetY + 40,
        size.width,
        offsetY,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => false;
}
