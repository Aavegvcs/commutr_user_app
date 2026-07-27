import 'package:flutter/material.dart';

// Brand color from Commutr styling
const Color kPrimaryGreen = Color(0xFF1B5E4C);
const Color kBackground = Color(0xFFF5F7FA);
const Color kFieldBorder = Color(0xFFD9DEE3);
const Color kFieldText = Color(0xFF9AA3AC);
const Color kLabelText = Color(0xFF1B5E4C);

class CommutrLtrProfileScreen extends StatelessWidget {
  /// User's full name from `GET /User/me`. `null`/empty falls back to a dash.
  final String? name;

  /// User's registered mobile number.
  final String? mobileNumber;

  /// User's employee code.
  final String? employeeCode;

  const CommutrLtrProfileScreen({
    super.key,
    this.name,
    this.mobileNumber,
    this.employeeCode,
  });

  static String _orDash(String? value) {
    final s = value?.trim();
    return (s == null || s.isEmpty) ? '-' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: back arrow + "Profile"
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back,
                      color: kPrimaryGreen,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      color: kPrimaryGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // "Personal Details" section title with divider line
              Row(
                children: [
                  const Text(
                    'Personal Details',
                    style: TextStyle(
                      color: kPrimaryGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: kFieldBorder,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name
              _LabeledField(
                label: 'Name',
                value: _orDash(name),
              ),
              const SizedBox(height: 20),

              // Mobile No.
              _LabeledField(
                label: 'Mobile No.',
                value: _orDash(mobileNumber),
              ),
              const SizedBox(height: 20),

              // Employee ID
              _LabeledField(
                label: 'Employee ID',
                value: _orDash(employeeCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kLabelText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kFieldBorder),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: kFieldText,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// Example usage:
// void main() => runApp(MaterialApp(home: const CommutrLtrProfileScreen(), debugShowCheckedModeBanner: false));