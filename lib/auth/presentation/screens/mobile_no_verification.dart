import 'package:commutr_main/auth/bloc/auth_bloc.dart';
import 'package:commutr_main/auth/bloc/auth_event.dart';
import 'package:commutr_main/auth/bloc/auth_state.dart';
import 'package:commutr_main/auth/presentation/screens/otp_verify_screen.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:commutr_main/auth/presentation/screens/signup.dart';

class MobileNoVerification extends StatefulWidget {
  const MobileNoVerification({super.key});

  @override
  State<MobileNoVerification> createState() => _MobileNoVerificationState();
}

class _MobileNoVerificationState extends State<MobileNoVerification> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  /// Shown after failed submit; cleared on first keystroke.
  String? _phoneFieldError;

  static const Color _darkGreen = Color(0xFF1B5E4B);
  static const Color _inputBackground = Color(0xFFEEF5F2);
  static const Color _phoneErrorBackground = Color(0xFFFFF5F5);
  static const Color _phoneErrorBorder = Color(0xFFE57373);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGrey = Color(0xFF666666);
  static const Color _dividerColor = Color(0xFFCCCCCC);
  static const Color _linkColor = Color(0xFF2E8B6E);

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  /// Indian mobile: 10 digits, starting with 6–9.
  String? _validatePhone(String? value) {
    final digits = value?.trim() ?? '';
    if (digits.isEmpty) {
      return 'Mobile number is required';
    }
    if (digits.length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpRequestSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: _darkGreen,
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerifyScreen(otp: state.contactNumber),
              ),
            );
          } else if (state is OtpRequestFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Form(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _buildLogoBar(),
                      ),
                      _buildHeroImage(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 28),
                            const Text(
                              'Your Everyday\nCommute Partner',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: _darkGreen,
                                height: 1.25,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Sign in to sync your transit journals and live\njourney alerts.',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textGrey,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Phone Number',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPhoneField(),
                            if (_phoneFieldError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _phoneFieldError!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.2,
                                    color: Colors.redAccent),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _buildSendOtpButton(context, state),
                            const SizedBox(height: 20),
                            _buildSignUpRow(),
                            const SizedBox(height: 20),
                            _buildTermsText(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/app_logo.png', width: 136, height: 25, fit: BoxFit.cover,)
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteIcon() {
    return SizedBox(
      width: 32,
      height: 22,
      child: CustomPaint(
        painter: _RouteIconPainter(),
      ),
    );
  }

  Widget _buildHeroImage() {
    return  _buildCarPlaceholder();
  }

  // ✅ FIXED: Image now uses full screen width and fixed height of 284
  Widget _buildCarPlaceholder() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16), // Full screen width
      height: 234,                 // Fixed height as required
      child: ClipRRect(
    borderRadius: const BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
    ),
        child: Image.asset(
          'assets/images/commutr_car_login.png',
          fit: BoxFit.cover,         // Ensures the image covers the area without distortion
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    final hasError = _phoneFieldError != null;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      decoration: BoxDecoration(
        color: hasError ? _phoneErrorBackground : _inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError
              ? _phoneErrorBorder
              : (_phoneFocus.hasFocus ? _darkGreen : Colors.transparent),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '+91',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 26,
            color: _dividerColor,
          ),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                fontSize: 15,
                color: _textDark,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Please enter your mobile no',
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                // errorText: _phoneFieldError,
                errorStyle: const TextStyle(fontSize: 12, height: 1.2),
              ),
              onChanged: (_) {
                if (_phoneFieldError != null) {
                  setState(() => _phoneFieldError = null);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendOtpButton(BuildContext context, AuthState state) {
    final isLoading = state is OtpRequestLoading;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                final err = _validatePhone(_phoneController.text);
                setState(() => _phoneFieldError = err);
                if (err != null) return;
                context
                    .read<AuthBloc>()
                    .add(RequestOtpEvent(_phoneController.text));
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                'Send OTP',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
  Widget _buildSignUpRow() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(
              fontSize: 13.5,
              color: _textGrey,
              fontWeight: FontWeight.w400,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SignupScreen()),
              );
            },
            child: const Text(
              'Sign Up',
              style: TextStyle(
                fontSize: 13.5,
                color: _linkColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 11.5,
            color: _textGrey,
            height: 1.6,
          ),
          children: [
            TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            TextSpan(text: '\nand '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painters ─────────────────────────────────────────────────────────

class _RouteIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    paint.color = const Color(0xFF888888);
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      paint,
    );

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1B5E4B);
    canvas.drawCircle(Offset(8, size.height / 2), 5, dotPaint);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF1B5E4B);
    canvas.drawCircle(Offset(size.width - 8, size.height / 2), 4, outlinePaint);

    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1B5E4B);
    canvas.drawCircle(Offset(size.width - 8, size.height / 2), 2, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final shadowPath = Path();
    shadowPath.addOval(Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 8),
      width: size.width * 0.75,
      height: 14,
    ));
    canvas.drawPath(shadowPath, shadowPaint);

    final bodyPath = Path();
    bodyPath.moveTo(size.width * 0.05, size.height * 0.65);
    bodyPath.lineTo(size.width * 0.05, size.height * 0.80);
    bodyPath.quadraticBezierTo(
        size.width * 0.05, size.height * 0.90,
        size.width * 0.12, size.height * 0.90);
    bodyPath.lineTo(size.width * 0.88, size.height * 0.90);
    bodyPath.quadraticBezierTo(
        size.width * 0.95, size.height * 0.90,
        size.width * 0.95, size.height * 0.80);
    bodyPath.lineTo(size.width * 0.95, size.height * 0.65);
    bodyPath.close();
    canvas.drawPath(bodyPath, paint);

    final roofPath = Path();
    roofPath.moveTo(size.width * 0.18, size.height * 0.65);
    roofPath.lineTo(size.width * 0.24, size.height * 0.30);
    roofPath.quadraticBezierTo(
        size.width * 0.28, size.height * 0.18,
        size.width * 0.36, size.height * 0.16);
    roofPath.lineTo(size.width * 0.72, size.height * 0.16);
    roofPath.quadraticBezierTo(
        size.width * 0.80, size.height * 0.17,
        size.width * 0.84, size.height * 0.30);
    roofPath.lineTo(size.width * 0.90, size.height * 0.65);
    roofPath.close();
    canvas.drawPath(roofPath, paint);

    final windowPaint = Paint()
      ..color = const Color(0xFF87CEEB).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final frontWindow = Path();
    frontWindow.moveTo(size.width * 0.20, size.height * 0.62);
    frontWindow.lineTo(size.width * 0.26, size.height * 0.32);
    frontWindow.quadraticBezierTo(
        size.width * 0.29, size.height * 0.22,
        size.width * 0.36, size.height * 0.20);
    frontWindow.lineTo(size.width * 0.46, size.height * 0.20);
    frontWindow.lineTo(size.width * 0.43, size.height * 0.62);
    frontWindow.close();
    canvas.drawPath(frontWindow, windowPaint);

    final rearWindow = Path();
    rearWindow.moveTo(size.width * 0.58, size.height * 0.62);
    rearWindow.lineTo(size.width * 0.56, size.height * 0.20);
    rearWindow.lineTo(size.width * 0.72, size.height * 0.20);
    rearWindow.quadraticBezierTo(
        size.width * 0.78, size.height * 0.21,
        size.width * 0.82, size.height * 0.32);
    rearWindow.lineTo(size.width * 0.87, size.height * 0.62);
    rearWindow.close();
    canvas.drawPath(rearWindow, windowPaint);

    final wheelPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;
    final hubPaint = Paint()
      ..color = const Color(0xFFAAAAAA)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
        Offset(size.width * 0.22, size.height * 0.88), 13, wheelPaint);
    canvas.drawCircle(
        Offset(size.width * 0.22, size.height * 0.88), 7, hubPaint);

    canvas.drawCircle(
        Offset(size.width * 0.76, size.height * 0.88), 13, wheelPaint);
    canvas.drawCircle(
        Offset(size.width * 0.76, size.height * 0.88), 7, hubPaint);

    final headlightPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.06, size.height * 0.68, size.width * 0.06, 8),
        const Radius.circular(3),
      ),
      headlightPaint,
    );

    final taillightPaint = Paint()
      ..color = const Color(0xFFEF9A9A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.88, size.height * 0.68, size.width * 0.05, 8),
        const Radius.circular(3),
      ),
      taillightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}