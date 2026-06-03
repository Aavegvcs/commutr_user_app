import 'dart:async';

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/welcome/presentation/screen/welcome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otp_autofill/otp_autofill.dart';

import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';

class OtpVerifyScreen extends StatefulWidget {
  /// NOTE: existing API kept intact – `otp` is actually the contact number
  /// that the OTP was sent to (used as the verification identifier).
  final String otp;
  const OtpVerifyScreen({super.key, required this.otp});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with WidgetsBindingObserver {
  static const Color primaryGreen = Color(0xFF1A6B3C);
  static const Color lightGreen = Color(0xFF4CAF50);

  static const int _otpLength = 6;
  static const int _resendDurationSeconds = 45;

  /// Optional: if your DLT-registered sender ID maps to a normalised phone
  /// number, set it here so the consent dialog ONLY fires for SMS from
  /// that sender. Leave `null` to accept any non-contact sender.
  static const String? _senderPhone = null;

  late final AuthBloc _authBloc;
  late final OTPInteractor _otpInteractor;
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  int _resendSeconds = _resendDurationSeconds;
  Timer? _timer;
  bool _hasError = false;

  /// Guards against double-submission once auto-fill triggers verify.
  bool _autoSubmitted = false;

  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>();
    _otpInteractor = OTPInteractor();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    WidgetsBinding.instance.addObserver(this);
    _startUserConsentListener();
    _startTimer();
  }

  // ───────────────────────── SMS User Consent API ─────────────────────────
  //
  // This is the same mechanism Zomato / Swiggy / Paytm use.
  //  • Works with ANY SMS format – no `<#>` prefix, no 11-char hash.
  //  • Requires NO Android permissions.
  //  • Shows a small system dialog "Allow app to read SMS?" the first time
  //    a matching SMS arrives. Tapping Allow returns the full SMS body.
  //  • Listener lives for ~5 minutes per call.
  //
  // Reference: https://developers.google.com/identity/sms-retriever/user-consent/overview

  Future<void> _startUserConsentListener() async {
    if (_isListening) return;
    _isListening = true;
    _log('User Consent listener: starting…');

    try {
      final smsBody = await _otpInteractor.startListenUserConsent(
        _senderPhone,
      );
      _log('User Consent listener: SMS received → "$smsBody"');
      if (!mounted) return;

      final extracted = _extractOtp(smsBody);
      if (extracted == null) {
        _log('User Consent listener: could not extract $_otpLength-digit OTP');
        _isListening = false;
        return;
      }
      _handleAutoFilledCode(extracted);
    } on PlatformException catch (e) {
      _log('User Consent listener: PlatformException → ${e.code} / ${e.message}');
      _isListening = false;
    } catch (e) {
      // Either TimeoutException (5-minute window expired) or user denied.
      // Manual entry still works perfectly.
      _log('User Consent listener: finished with $e');
      _isListening = false;
    }
  }

  Future<void> _stopUserConsentListener() async {
    if (!_isListening) return;
    try {
      await _otpInteractor.stopListenForCode();
      _log('User Consent listener: stopped');
    } catch (e) {
      _log('User Consent listener: stop failed → $e');
    }
    _isListening = false;
  }

  /// Pulls a 6-digit number out of the SMS body. The DLT template is:
  ///   "Hi, your OTP is 123456 for login to Commutr app. ..."
  /// so the first run of exactly 6 consecutive digits is the OTP.
  String? _extractOtp(String? smsBody) {
    if (smsBody == null || smsBody.isEmpty) return null;

    // Strict: exactly 6 digits with no digit on either side.
    final strictMatch = RegExp(r'(?<!\d)\d{6}(?!\d)').firstMatch(smsBody);
    if (strictMatch != null) return strictMatch.group(0);

    // Fallback: first run of 6+ digits anywhere.
    final looseMatch = RegExp(r'\d{6,}').firstMatch(smsBody)?.group(0);
    if (looseMatch != null && looseMatch.length >= _otpLength) {
      return looseMatch.substring(0, _otpLength);
    }
    return null;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[OTP-CONSENT] $message');
  }

  // ─────────────────────────── Lifecycle handling ─────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        _resendSeconds > 0 &&
        !_autoSubmitted &&
        !_isListening) {
      _startUserConsentListener();
    }
  }

  // ───────────────────────── Auto-fill core logic ────────────────────────

  void _handleAutoFilledCode(String otp) {
    if (!mounted || _autoSubmitted) return;
    if (otp.length < _otpLength) return;

    final code = otp.substring(0, _otpLength);
    _log('auto-filling OTP boxes with: $code');

    for (var i = 0; i < _otpLength; i++) {
      _controllers[i].text = code[i];
    }
    FocusScope.of(context).unfocus();
    if (_hasError) setState(() => _hasError = false);

    _autoSubmitted = true;
    _stopUserConsentListener();
    _authBloc.add(OtpVerifyEvent(widget.otp, code));
  }

  // ──────────────────────────────── Misc ─────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = _resendDurationSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopUserConsentListener();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _authBloc.close();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_resendSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_resendSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onOtpChanged(String value, int index) {
    if (_hasError) setState(() => _hasError = false);

    if (value.length > 1) {
      // Keep only the last digit typed (handles replace-on-full-box edge case).
      final digit = value[value.length - 1];
      _controllers[index].value = TextEditingValue(
        text: digit,
        selection: TextSelection.collapsed(offset: 1),
      );
      if (index < _otpLength - 1) _focusNodes[index + 1].requestFocus();
      return;
    }

    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  Future<void> _onResendPressed() async {
    _autoSubmitted = false;
    for (final c in _controllers) {
      c.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes.first.requestFocus();
    }
    _startTimer();
    await _stopUserConsentListener();
    _startUserConsentListener();
    _authBloc.add(RequestOtpEvent(widget.otp));
  }

  void _onManualVerifyPressed() {
    final code = _enteredOtp;
    if (code.length < _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }
    _authBloc.add(OtpVerifyEvent(widget.otp, code));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OtpVerifySuccess) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Welcome()),
              (_) => false,
            );
          } else if (state is OtpVerifyFailure) {
            _autoSubmitted = false;
            // Re-arm the consent listener so a follow-up SMS could still
            // be picked up.
            if (!_isListening) _startUserConsentListener();
            setState(() => _hasError = true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (state is OtpRequestSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: primaryGreen,
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
          final isLoading = state is OtpRequestLoading;
          return Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: const Icon(Icons.arrow_back,
                              color: primaryGreen, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Personal Details',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirm Identity',
                          style: TextStyle(
                            color: primaryGreen,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "We've sent a 6-digit verification code to your\nregistered mobile number:",
                          style: TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 15,
                              height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.otp,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 36),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(_otpLength, (index) {
                            return _OtpBox(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              onChanged: (val) => _onOtpChanged(val, index),
                              hasError: _hasError,
                              onBackspaceOnEmpty: index > 0
                                  ? () => _focusNodes[index - 1].requestFocus()
                                  : null,
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        if (_resendSeconds > 0)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: lightGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'RESEND IN $_formattedTime',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: _resendSeconds == 0 ? 0.4 : 1,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: (isLoading || _resendSeconds == 0)
                                  ? null
                                  : _onManualVerifyPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white),
                                    )
                                  : const Text(
                                      'Verify',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed:
                                _resendSeconds == 0 ? _onResendPressed : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryGreen,
                              side: const BorderSide(
                                  color: Color(0xFFCCCCCC), width: 1.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 20,
                                color: primaryGreen),
                            label: const Text(
                              'Resend code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Center(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                              color: Color(0xFF888888), fontSize: 13),
                          children: [
                            TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500),
                            ),
                            TextSpan(text: '  and\n'),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;
  final VoidCallback? onBackspaceOnEmpty;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
    this.onBackspaceOnEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete) &&
              controller.text.isEmpty) {
            onBackspaceOnEmpty?.call();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: hasError ? const Color(0xFFFFEBEB) : const Color(0xFFEEEEEE),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: hasError
                  ? const BorderSide(color: Colors.redAccent, width: 1.8)
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: hasError
                  ? const BorderSide(color: Colors.redAccent, width: 1.8)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.redAccent : const Color(0xFF1A6B3C),
                width: 1.8,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
