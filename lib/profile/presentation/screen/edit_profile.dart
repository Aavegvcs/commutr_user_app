import 'package:commutr_main/profile/presentation/profile_user_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    required this.initialData,
  });

  final ProfileUserData initialData;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;

  late String _selectedGender;
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _applyFromData(widget.initialData);
    final names = widget.initialData.firstAndLastName;
    _firstNameController = TextEditingController(text: names.$1);
    _lastNameController = TextEditingController(text: names.$2);
    _mobileController = TextEditingController(
      text: widget.initialData.formattedPhone,
    );
    _emailController = TextEditingController(text: widget.initialData.email);
    _addressController = TextEditingController(text: widget.initialData.address);
    _cityController = TextEditingController(text: widget.initialData.city);
    _stateController = TextEditingController(text: widget.initialData.state);
    _pincodeController = TextEditingController(text: widget.initialData.pincode);
  }

  void _applyFromData(ProfileUserData data) {
    _selectedGender = _genders.contains(data.gender) ? data.gender : _genders.first;
  }

  void _resetFormToInitial() {
    final d = widget.initialData;
    final names = d.firstAndLastName;
    _firstNameController.text = names.$1;
    _lastNameController.text = names.$2;
    _mobileController.text = d.formattedPhone;
    _emailController.text = d.email;
    _addressController.text = d.address;
    _cityController.text = d.city;
    _stateController.text = d.state;
    _pincodeController.text = d.pincode;
    setState(() => _applyFromData(d));
  }

  static const Color _primaryGreen = Color(0xFF1A6B4A);
  static const Color _fieldBg = Color(0xFFECF5EE);
  static const Color _bgColor = Color(0xFFF3F7F4);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryGreen),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Profile Edit',
          style: TextStyle(
            color: _primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFCFE3D4),
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Color(0xFFA8C7B0),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: _primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'CHANGE PHOTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Personal Details Section
              _buildSectionHeader('Personal Details'),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: 'FIRST NAME',
                      child: _buildTextField(
                        controller: _firstNameController,
                        hintText: 'First Name',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          if (val.trim().length < 2) return 'Min 2 chars';
                          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) return 'Letters only';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildLabeledField(
                      label: 'LAST NAME',
                      child: _buildTextField(
                        controller: _lastNameController,
                        hintText: 'Last Name',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          if (val.trim().length < 2) return 'Min 2 chars';
                          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val)) return 'Letters only';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender
              _buildLabeledField(
                label: 'GENDER',
                child: Row(
                  children: _genders.map((gender) {
                    final isSelected = _selectedGender == gender;
                    IconData icon;
                    switch (gender) {
                      case 'Male':
                        icon = Icons.male;
                        break;
                      case 'Female':
                        icon = Icons.female;
                        break;
                      default:
                        icon = Icons.do_not_disturb_on_outlined;
                    }
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: gender != 'Other' ? 8 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGender = gender),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? _primaryGreen : Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected ? _primaryGreen : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  gender,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // Contact Section
              _buildSectionHeader('Contact'),
              const SizedBox(height: 16),

              _buildLabeledField(
                label: 'MOBILE NO.',
                child: _buildTextField(
                  controller: _mobileController,
                  hintText: '+91 XXXXXXXXXX',
                  keyboardType: TextInputType.phone,
                  suffixIcon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Mobile number required';
                    final digits = val.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) return 'Enter valid mobile number';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              _buildLabeledField(
                label: 'EMAIL ID',
                child: _buildTextField(
                  controller: _emailController,
                  hintText: 'email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.mail_outline, size: 18, color: Colors.grey),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Email required';
                    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(val)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Location Section
              _buildSectionHeader('Location'),
              const SizedBox(height: 16),

              _buildLabeledField(
                label: 'CURRENT ADDRESS',
                child: _buildTextField(
                  controller: _addressController,
                  hintText: 'Enter your address',
                  maxLines: 3,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Address required';
                    if (val.trim().length < 5) return 'Enter a valid address';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      label: 'CITY',
                      child: _buildTextField(
                        controller: _cityController,
                        hintText: 'City',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLabeledField(
                      label: 'STATE',
                      child: _buildTextField(
                        controller: _stateController,
                        hintText: 'State',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLabeledField(
                      label: 'PINCODE',
                      child: _buildTextField(
                        controller: _pincodeController,
                        hintText: 'Pincode',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          if (val.length != 6) return '6 digits';
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Discard Button
              Center(
                child: TextButton(
                  onPressed: _handleDiscard,
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFCCDDD2), thickness: 1)),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    Widget? prefixIcon,
    Widget? suffixIcon,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: _fieldBg,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: prefixIcon != null ? 4 : 14,
          vertical: maxLines > 1 ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile saved successfully!'),
          backgroundColor: _primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix the errors before saving.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _handleDiscard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard Changes?'),
        content: const Text('All unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFormToInitial();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}