import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color _primaryGreen = Color(0xFF1B7A3E);
  static const Color _lightGreen = Color(0xFFE8F5EE);
  static const Color _iconGreen = Color(0xFF2E7D52);
  static const Color _bgColor = Color(0xFFF2F4F3);
  static const String _lastUpdated = '23 June 2026';

  static const List<_PolicySection> _sections = [
    _PolicySection(
      icon: Icons.info_outline,
      title: 'Introduction',
      body:
          'Commutr is committed to protecting your '
          'privacy. This Privacy Policy explains how we collect, use, store, '
          'and safeguard your information when you use the Commutr app and '
          'related services. By using the app, you agree to the practices '
          'described in this policy.',
    ),
    _PolicySection(
      icon: Icons.folder_outlined,
      title: 'Information We Collect',
      body:
          'We collect the following types of information:\n\n'
          '• Account details such as your name, email address, and mobile '
          'number.\n'
          '• Location data, including your home, work, and saved addresses, '
          'used to provide trip planning and live tracking.\n'
          '• Trip and booking history to improve our service and your '
          'experience.\n'
          '• Device information such as device model, operating system, and '
          'app version.',
    ),
    _PolicySection(
      icon: Icons.tune_outlined,
      title: 'How We Use Your Information',
      body:
          'Your information helps us to:\n\n'
          '• Provide, operate, and maintain ride and trip services.\n'
          '• Enable live tracking and route planning between your saved '
          'locations.\n'
          '• Verify your identity and secure your account.\n'
          '• Send trip reminders, updates, and important notifications.\n'
          '• Improve, personalize, and develop new features.',
    ),
    _PolicySection(
      icon: Icons.location_on_outlined,
      title: 'Location Data',
      body:
          'Commutr uses your location to offer accurate pickup points, nodal '
          'points, route navigation, and live tracking. You can manage '
          'location permissions at any time through your device settings. '
          'Disabling location may limit certain features of the app.',
    ),
    _PolicySection(
      icon: Icons.share_outlined,
      title: 'Sharing Your Information',
      body:
          'We do not sell your personal information. We may share data with:\n\n'
          '• Service providers and partners who help operate the app.\n'
          '• Transport operators to fulfil your bookings.\n'
          '• Authorities when required by law or to protect our rights.\n\n'
          'All third parties are required to keep your information secure and '
          'use it only for the agreed purposes.',
    ),
    _PolicySection(
      icon: Icons.lock_outline,
      title: 'Data Security',
      body:
          'We use industry-standard safeguards to protect your data against '
          'unauthorized access, alteration, or disclosure. However, no method '
          'of transmission over the internet is completely secure, and we '
          'cannot guarantee absolute security.',
    ),
    _PolicySection(
      icon: Icons.verified_user_outlined,
      title: 'Your Rights',
      body:
          'You have the right to access, update, or delete your personal '
          'information. You can edit most details directly in your profile, or '
          'contact us to request changes or account deletion.',
    ),
    _PolicySection(
      icon: Icons.update_outlined,
      title: 'Changes to This Policy',
      body:
          'We may update this Privacy Policy from time to time. Any changes '
          'will be posted within the app, and the "Last updated" date above '
          'will be revised accordingly. We encourage you to review this policy '
          'periodically.',
    ),
    _PolicySection(
      icon: Icons.mail_outline,
      title: 'Contact Us',
      body:
          'If you have any questions or concerns about this Privacy Policy or '
          'your data, please reach out to us at:\n\n'
          'Email: support@commutr.com',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(
                      Icons.arrow_back,
                      color: _primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: _primaryGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  // Header card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _lightGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.privacy_tip_outlined,
                              color: _iconGreen,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your privacy matters',
                                style: TextStyle(
                                  color: _primaryGreen,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Learn how Commutr collects, uses, and protects your '
                          'personal information.',
                          style: TextStyle(
                            color: Color(0xFF4A5A50),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Last updated: $_lastUpdated',
                          style: const TextStyle(
                            color: _iconGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Policy sections
                  for (final section in _sections) ...[
                    _buildSectionCard(section),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(_PolicySection section) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(section.icon, color: _iconGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            section.body,
            style: const TextStyle(
              color: Color(0xFF4A5A50),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection {
  final IconData icon;
  final String title;
  final String body;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.body,
  });
}
