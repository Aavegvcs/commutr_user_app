import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_home/commutr_ltr_home.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_login/ltr_session_storage.dart';
import 'package:commutr_main/core/network/api_constants.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';

// Colors matching the design
const Color kPrimaryGreen = Color(0xFF1B5E4C);
const Color kLightGreenBg = Color(0xFFE6F1EC);
const Color kFieldBorder = Color(0xFFE0E0E0);
const Color kHintGrey = Color(0xFFAAAAAA);
const Color kLabelGrey = Color(0xFF444444);

class CommutrLtrLogin extends StatefulWidget {
  const CommutrLtrLogin({super.key});

  @override
  State<CommutrLtrLogin> createState() => _CommutrLtrLoginState();
}

class _CommutrLtrLoginState extends State<CommutrLtrLogin> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _empIdController = TextEditingController();

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.ltrGuestBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final LtrSessionStorage _session = LtrSessionStorage();

  /// True while the lookup request is in flight.
  bool _lookingUp = false;

  /// True while the login request is in flight.
  bool _loggingIn = false;

  /// True once a user was found and name/emp-id were prefilled from the API.
  /// When set, those fields are locked (read-only).
  bool _prefilled = false;

  /// The mobile number the last lookup ran for, so we don't fire twice.
  String? _lastLookedUp;

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_onMobileChanged);
  }

  @override
  void dispose() {
    _mobileController.removeListener(_onMobileChanged);
    _mobileController.dispose();
    _nameController.dispose();
    _empIdController.dispose();
    _dio.close();
    super.dispose();
  }

  void _onMobileChanged() {
    final mobile = _mobileController.text.trim();

    // Fewer than 10 digits — reset any prefilled state so the user can
    // start over / edit freely.
    if (mobile.length < 10) {
      _lastLookedUp = null;
      if (_prefilled) {
        setState(() {
          _prefilled = false;
          _nameController.clear();
          _empIdController.clear();
        });
      }
      return;
    }

    // Exactly 10 digits and not already looked up — fire the lookup.
    if (mobile.length == 10 && mobile != _lastLookedUp && !_lookingUp) {
      _lookupUser(mobile);
    }
  }

  Future<void> _lookupUser(String mobile) async {
    _lastLookedUp = mobile;
    FocusScope.of(context).unfocus();
    setState(() => _lookingUp = true);

    try {
      final response = await _dio.get<dynamic>('/User/lookup/$mobile');

      final data = response.data;
      final result = (data is Map) ? data['result'] : null;

      if (response.statusCode == 200 && result is Map) {
        final fullName = (result['fullName'] ?? '').toString();
        final employeeCode = (result['employeeCode'] ?? '').toString();

        if (!mounted) return;
        setState(() {
          _nameController.text = fullName;
          _empIdController.text = employeeCode;
          _prefilled = true;
          _lookingUp = false;
        });
        _showMessage(
            'Welcome back${fullName.isNotEmpty ? ', $fullName' : ''}!');
      } else {
        _handleUserNotFound();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _handleUserNotFound();
      } else {
        if (!mounted) return;
        setState(() {
          _prefilled = false;
          _lookingUp = false;
        });
        // Allow a retry on real errors (timeouts, no network, 5xx).
        _lastLookedUp = null;
        _showMessage('Could not verify number. Please enter your details.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prefilled = false;
        _lookingUp = false;
      });
      _lastLookedUp = null;
      _showMessage('Something went wrong. Please enter your details.');
    }
  }

  /// No account for this number — let the user fill the fields in themselves.
  void _handleUserNotFound() {
    if (!mounted) return;
    setState(() {
      _prefilled = false;
      _lookingUp = false;
      _nameController.clear();
      _empIdController.clear();
    });
    _showMessage('New here? Please fill in your details to continue.');
  }

  Future<void> _onLoginPressed() async {
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();
    final empId = _empIdController.text.trim();

    if (mobile.length != 10) {
      _showMessage('Please enter a valid 10-digit mobile number.');
      return;
    }
    if (name.isEmpty) {
      _showMessage('Please enter your full name.');
      return;
    }
    if (empId.isEmpty) {
      _showMessage('Please enter your employee ID.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loggingIn = true);

    try {
      final response = await _dio.post<dynamic>(
        '/Auth/login',
        data: <String, dynamic>{
          'mobileNumber': mobile,
          'name': name,
          'employeeCode': empId,
        },
      );

      final data = response.data;
      final isSuccess = (data is Map) && data['isSuccess'] == true;
      final result = (data is Map) ? data['result'] : null;

      if (response.statusCode == 200 && isSuccess && result is Map) {
        final accessToken = (result['accessToken'] ?? '').toString();
        final refreshToken = (result['refreshToken'] ?? '').toString();

        if (accessToken.isEmpty) {
          if (!mounted) return;
          setState(() => _loggingIn = false);
          _showMessage('Login failed. Please try again.');
          return;
        }

        await _session.saveSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          mobileNumber: mobile,
          name: name,
          employeeCode: empId,
        );

        if (!mounted) return;
        setState(() => _loggingIn = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const CommutrLtrHome(),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() => _loggingIn = false);
        final message = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Login failed. Please try again.';
        _showMessage(message);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loggingIn = false);
      final message = (e.response?.data is Map &&
              (e.response?.data as Map)['message'] is String)
          ? (e.response?.data as Map)['message'] as String
          : 'Could not log in. Please check your connection and try again.';
      _showMessage(message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingIn = false);
      _showMessage('Something went wrong. Please try again.');
    }
  }

  // Snackbars are intentionally suppressed on this screen.
  void _showMessage(String message) {}

  bool get _mobileComplete => _mobileController.text.trim().length == 10;

  /// Always leave the LTR login screen back to the mobile-number verification
  /// screen, clearing anything else on the stack.
  void _goToMobileVerification() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const MobileNoVerification(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goToMobileVerification();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAvatarWithDecorations(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTitleSection(),
                      const SizedBox(height: 24),
                      _buildFormCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildLoginButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------
  Widget _buildHeader() {
    return Row(
      children: [
        InkWell(
          onTap: _goToMobileVerification,
          borderRadius: BorderRadius.circular(24),
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(Icons.arrow_back, color: kPrimaryGreen, size: 26),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Login',
          style: TextStyle(
            color: kPrimaryGreen,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ---------- Avatar with decorative plus signs ----------
  Widget _buildAvatarWithDecorations() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 88,
          width: 88,
          decoration: const BoxDecoration(
            color: kLightGreenBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 50,
            color: Color(0xFF9BB8AC),
          ),
        ),
      ],
    );
  }

  // ---------- Title + subtitle ----------
  Widget _buildTitleSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Let's Get You Started",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Please enter your details below to continue',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ---------- Form Card ----------
  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kFieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Mobile Number'),
          const SizedBox(height: 8),
          _buildMobileField(),
          const SizedBox(height: 20),
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            readOnly: _prefilled,
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('Employee ID'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _empIdController,
            hint: 'Enter your employee ID',
            icon: Icons.badge_outlined,
            readOnly: _prefilled,
          ),
          if (_prefilled) ...[
            const SizedBox(height: 10),
            _buildPrefilledNote(),
          ],
          const SizedBox(height: 20),
          _buildSecureInfoBanner(),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: kLabelGrey,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMobileField() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: kFieldBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_iphone, color: kPrimaryGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: 'Enter 10-digit mobile number',
                hintStyle: TextStyle(color: kHintGrey, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildMobileTrailing(),
        ],
      ),
    );
  }

  /// Loader while looking up, a green check once a user was prefilled.
  Widget _buildMobileTrailing() {
    if (_lookingUp) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(kPrimaryGreen),
        ),
      );
    }
    if (_prefilled && _mobileComplete) {
      return Container(
        height: 22,
        width: 22,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 14),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool readOnly = false,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: readOnly ? kLightGreenBg : Colors.white,
        border: Border.all(color: kFieldBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: kHintGrey, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (readOnly)
            const Icon(Icons.lock_outline, color: kPrimaryGreen, size: 18),
        ],
      ),
    );
  }

  Widget _buildPrefilledNote() {
    return Row(
      children: [
        const Icon(Icons.verified_user_outlined,
            color: kPrimaryGreen, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Details fetched from your account.',
            style: TextStyle(
              fontSize: 12.5,
              color: kPrimaryGreen.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecureInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kLightGreenBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 26,
            width: 26,
            decoration: const BoxDecoration(
              color: kPrimaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your information is secure and will only be used to create your account.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF333333),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Login Button ----------
  Widget _buildLoginButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: (_lookingUp || _loggingIn) ? null : _onLoginPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryGreen,
            disabledBackgroundColor: kPrimaryGreen.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
          child: _loggingIn
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'LOGIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
