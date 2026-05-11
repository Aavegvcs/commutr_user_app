import 'dart:convert';

import 'package:commutr_main/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/auth/presentation/screens/pin_map/location_data.dart';
import 'package:commutr_main/auth/presentation/screens/pin_map/pin_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:commutr_main/auth/presentation/screens/signup_success.dart';


class SignupScreen extends StatefulWidget {
  final LocationData ? locationData;

  const SignupScreen({super.key, this.locationData});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _selectedGender = 'Male';
  final TextEditingController companyCodeController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _officeHubController = TextEditingController();
  bool _isLoading = false;
  double? _empLat;
  double? _empLng;
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://13.235.144.192:5001',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },

  ));

  static const Color _primaryGreen = Color(0xFF1A5C45);
  static const Color _lightGreenBg = Color(0xFFEBF5F0);
  static const Color _cardBg = Color(0xFFF0F7F4);
  static const Color _dividerColor = Color(0xFFB0CCBF);

  // API Endpoint
  static const String _apiPath = '/api/v1/UserStages';

  @override
  void initState() {
    super.initState();
    final loc = widget.locationData;
    if (loc != null) {
      _cityController.text = loc.city;
      _stateController.text = loc.state;
      final pin = loc.pincode.trim();
      if (pin.isNotEmpty && pin != 'N/A') {
        _pincodeController.text = pin;
      }
      _empLat = loc.latitude;
      _empLng = loc.longitude;
    }
  }

  @override
  void dispose() {
    companyCodeController.dispose();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _officeHubController.dispose();
    _dio.close();
    super.dispose();
  }

  // Helper method to split full name into first and last name
  Map<String, String> _splitFullName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return {'firstName': '', 'lastName': ''};
    final parts = trimmed.split(' ');
    if (parts.length == 1) {
      return {'firstName': parts[0], 'lastName': ''};
    }
    final firstName = parts.first;
    final lastName = parts.sublist(1).join(' ');
    return {'firstName': firstName, 'lastName': lastName};
  }

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _mobileRegex = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _pincodeRegex = RegExp(r'^\d{6}$');

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Clears routes above verification (e.g. pin map) so back never stops on an intermediate screen.
  void _goBackToMobileVerification() {
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MobileNoVerification(),
      ),
      (route) => false,
    );
  }

  Future<void> _submitForm() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nameParts = _splitFullName(_fullNameController.text.trim());

      // Build request body according to API specification
      final Map<String, dynamic> requestBody = {
        "locCode": null,
        "depCode": null,
        "proCode": null,
        "lobCode": null,
        "gender": selectedGender(_selectedGender) ,
        "city": _cityController.text.trim(),
        "pin": _pincodeController.text.trim(),
        "state": _stateController.text.trim(),
        "stateCode": null,
        "phoneNo": null,
        "emerContactNo": null,
        "address": null,
        "supId": null,
        "empType": null,
        "empTypeId": 1,
        "transport": null,
        "useDayPickupPoint": null,
        "nodalPick": null,
        "nodalDrop": null,
        "geocodeId": null,
        "empLat": _empLat,
        "empLng": _empLng,
        "locationName": _officeHubController.text.trim(),
        "employeeId": null,
        "firstName": nameParts['firstName'],
        "middleName": null,
        "lastName": nameParts['lastName'],
        "mobileNo": _mobileController.text.trim().replaceAll(RegExp(r'\s'), ''),
        "emailId": _emailController.text.trim(),
        "specialNeeds": null,
        "supEmployeeId": null,
        "spocEmployeeId": null,
        "spoc": null,
        "tpin": null,
        "actionType": null,
        "supervisorName": null,
        "departmentName": null,
        "projectName": null,
        "regisLocation": null,
        "ipAddress": null
      };

      // ─── DEBUG LOGS ───────────────────────────────────────────────
      debugPrint('┌─────────────────────────────────────────');
      debugPrint('│ 🌐 URL     : ${_dio.options.baseUrl}$_apiPath');
      debugPrint('│ 📤 HEADERS : X-CorporateCode = ${companyCodeController.text}');
      debugPrint('│ 📦 REQUEST : ${jsonEncode(requestBody)}');
      debugPrint('└─────────────────────────────────────────');
      // ─────────────────────────────────────────────────────────────

      // Make POST request using Dio
      final response = await _dio.post(
        _apiPath,
        data: requestBody,
        options: Options(
          headers: {
            'X-CorporateCode': companyCodeController.text,
          },
        ),
      );

      // ─── DEBUG LOGS ───────────────────────────────────────────────
      debugPrint('┌─────────────────────────────────────────');
      debugPrint('│ ✅ STATUS  : ${response.statusCode}');
      debugPrint('│ 📥 RESPONSE: ${jsonEncode(response.data)}');
      debugPrint('└─────────────────────────────────────────');
      // ─────────────────────────────────────────────────────────────

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SignupSuccessScreen()),
          (route) => false,
        );
        _clearForm();
      } else {
        _showSnackBar('Server error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (!mounted) return;

      // ─── DEBUG LOGS ───────────────────────────────────────────────
      debugPrint('┌─────────────────────────────────────────');
      debugPrint('│ ❌ DIO ERROR TYPE   : ${e.type}');
      debugPrint('│ ❌ DIO ERROR MSG    : ${e.message}');
      debugPrint('│ ❌ DIO STATUS CODE  : ${e.response?.statusCode}');
      debugPrint('│ ❌ DIO RESPONSE DATA: ${jsonEncode(e.response?.data)}');
      debugPrint('└─────────────────────────────────────────');
      // ─────────────────────────────────────────────────────────────

      String errorMessage = 'Network error';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout. Please try again.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server response timeout.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'No internet connection.';
      } else if (e.response != null) {
        errorMessage = 'Server error: ${e.response?.statusCode}';
      } else {
        errorMessage = e.message ?? 'Unknown error occurred';
      }

      _showSnackBar(errorMessage);
    } catch (e) {
      if (!mounted) return;

      // ─── DEBUG LOGS ───────────────────────────────────────────────
      debugPrint('┌─────────────────────────────────────────');
      debugPrint('│ 💥 UNEXPECTED ERROR: ${e.toString()}');
      debugPrint('└─────────────────────────────────────────');
      // ─────────────────────────────────────────────────────────────

      _showSnackBar('Unexpected error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _clearForm() {
    companyCodeController.clear();
    _fullNameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _cityController.clear();
    _stateController.clear();
    _pincodeController.clear();
    _officeHubController.clear();
    setState(() => _selectedGender = 'Male');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _goBackToMobileVerification();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _goBackToMobileVerification,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: Icon(Icons.arrow_back,
                          color: _primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Personal Details',
                      style: TextStyle(
                        color: _primaryGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            // Scrollable content
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                        // Account Details Card
                        _buildCard(
                          icon: Icons.person_outline,
                          title: 'Account Details',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: companyCodeController,
                                label: 'Company Code',
                              ),
                              const SizedBox(height: 4),
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                validator: _validateFullName,
                              ),
                              const SizedBox(height: 12),
                              _buildGenderSelector(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Connectivity Card
                        _buildCard(
                          icon: Icons.alternate_email,
                          title: 'Connectivity',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _mobileController,
                                label: 'Mobile No.',
                                keyboardType: TextInputType.phone,
                                validator: _validateMobile,
                                maxLength: 10,
                              ),
                              const SizedBox(height: 4),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email ID',
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              const SizedBox(height: 4),
                              _buildDropdown(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Residence Card
                        _buildResidenceCard(),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  ),
                  // Full screen loader overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('Submitting...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Fixed bottom submit
            Material(
              elevation: 8,
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Submit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String? _validateFullName(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter full name';
    if (t.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateMobile(String? value) {
    final t = (value ?? '').replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return 'Please enter mobile number';
    if (!_mobileRegex.hasMatch(t)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter email ID';
    if (!_emailRegex.hasMatch(t)) return 'Enter a valid email address';
    return null;
  }

  String? _validateCity(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter city';
    if (t.length < 2) return 'City name is too short';
    return null;
  }

  String? _validateState(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Please enter state';
    if (t.length < 2) return 'State name is too short';
    return null;
  }

  String? _validatePincode(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return 'Please enter pincode';
    if (!_pincodeRegex.hasMatch(t)) return 'Pincode must be 6 digits';
    return null;
  }

  String? _validateOfficeHub(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter office hub';
    return null;
  }

  String selectedGender(String gender) {
    switch (gender) {
      case 'Male':
        return 'M';

      case 'Female':
        return 'F';

      case 'Other':
        return 'O';

      default:
        return '';
    }
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _primaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _dividerColor, width: 1),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryGreen, width: 1.5),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red.shade400, width: 1),
            ),
            focusedErrorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
            ),
            errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 12),
            contentPadding: const EdgeInsets.only(bottom: 4),
            isDense: true,
            counterText: maxLength != null ? '' : null,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildGenderSelector() {
    final genders = ['Male', 'Female', 'Other'];
    return Row(
      children: [
        Text(
          'GENDER',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: genders.map((gender) {
                final isSelected = _selectedGender == gender;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedGender = gender),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        gender,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return _buildTextField(
      controller: _officeHubController,
      label: 'Office Hub',
      validator: _validateOfficeHub,
    );
  }

  Widget _buildResidenceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: _primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Residence',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              // Pin on Map button
              InkWell(
                splashColor: Colors.transparent,
                onTap: () async {
                  final loc = await Navigator.push<LocationData>(
                    context,
                    MaterialPageRoute(builder: (_) => const PinMapScreen()),
                  );
                  if (loc != null) {
                    _cityController.text = loc.city;
                    _stateController.text = loc.state;
                    final pin = loc.pincode.trim();
                    if (pin.isNotEmpty && pin != 'N/A') {
                      _pincodeController.text = pin;
                    }
                    setState(() {
                      _empLat = loc.latitude;
                      _empLng = loc.longitude;
                    });
                  }
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _lightGreenBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_searching,
                          color: _primaryGreen, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'PIN ON MAP',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Map preview
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 120,
              width: double.infinity,
              color: const Color(0xFF4A6FA5),
              child: Stack(
                children: [
                  // Simulated map background with grid lines
                  CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: _MapPainter(),
                  ),
                  // Location pin
                  const Center(
                    child: Icon(
                      Icons.location_pin,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // City and State row
          Row(
            children: [
              Expanded(
                child: _buildInlineTextField(
                  controller: _cityController,
                  label: 'City',
                  validator: _validateCity,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInlineTextField(
                  controller: _stateController,
                  label: 'State',
                  validator: _validateState,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          _buildTextField(
            controller: _pincodeController,
            label: 'Pincode',
            keyboardType: TextInputType.number,
            validator: _validatePincode,
            maxLength: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildInlineTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        border: InputBorder.none,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _dividerColor, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _primaryGreen, width: 1.5),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red.shade400, width: 1),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.red.shade700, width: 1.5),
        ),
        errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 12),
        contentPadding: const EdgeInsets.only(bottom: 4),
        isDense: true,
      ),
    );
  }
}

/// Custom painter to simulate a dark map grid
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient (dark teal/slate like map)
    final bgPaint = Paint();
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    bgPaint.shader = const LinearGradient(
      colors: [Color(0xFF3A5A7A), Color(0xFF2E4A6A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Grid lines (streets)
    final linePaint = Paint()
      ..color = const Color(0xFF5A7A9A).withOpacity(0.6)
      ..strokeWidth = 1.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 18) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Vertical lines
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Diagonal road
    final roadPaint = Paint()
      ..color = const Color(0xFF6A9ABF).withOpacity(0.7)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(0, size.height * 0.3),
      Offset(size.width, size.height * 0.7),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.8, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}