// data_privacy_consent_screen.dart
//
// Standalone Flutter screen replicating the "DataFiduciary Pvt. Ltd."
// Data Privacy Consent UI (DPDP Act, 2023 consent screen).
//
// Run directly:
//   flutter create temp_app && cp data_privacy_consent_screen.dart temp_app/lib/main.dart && cd temp_app && flutter run
//
// Or drop `DataPrivacyConsentScreen` into an existing app and route to it.

import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/welcome/presentation/screen/welcome.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------
class _Palette {
  static const headerTop = Color(0xFF4F9E85);
  static const headerBottom = Color(0xFF3D8A70);
  static const banner = Color(0xFFE7F5EF);
  static const bannerAccent = Color(0xFF4F9E85);
  static const cardBorder = Color(0xFFE6E6E4);
  static const chipBg = Color(0xFFDCF1E7);
  static const chipText = Color(0xFF2F7D63);
  static const iconGreen = Color(0xFF4F9E85);
  static const bodyGray = Color(0xFF6B6B6B);
  static const titleDark = Color(0xFF1F2320);
  static const link = Color(0xFF3E8E70);
  static const buttonGreen = Color(0xFF3D8A70);
}

class DataPrivacyConsentScreen extends StatefulWidget {
  const DataPrivacyConsentScreen({super.key});

  @override
  State<DataPrivacyConsentScreen> createState() =>
      _DataPrivacyConsentScreenState();
}

class _DataPrivacyConsentScreenState extends State<DataPrivacyConsentScreen> {
  bool _consentChecked = false;
  bool _ageChecked = false;

  bool get _canSubmit => _consentChecked && _ageChecked;

  Future<void> _handleSubmit() async {
    // Persist that consent has been recorded so this one-time screen is not
    // shown again on subsequent logins.
    await sl<AuthLocalStorage>().markDpdcaConsentSeen();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Welcome()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24, top: 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _InfoBanner(),
                          const SizedBox(height: 24),
                          const _SectionTitle('Data we collect'),
                          const SizedBox(height: 12),
                          const _DataItemCard(
                            icon: Icons.person_outline,
                            title: 'Identity & Contact',
                            subtitle: 'Name, email address, phone number',
                          ),
                          const SizedBox(height: 10),
                          const _DataItemCard(
                            icon: Icons.smartphone_outlined,
                            title: 'Device & Usage',
                            subtitle: 'Device identifiers, app usage patterns',
                          ),
                          const SizedBox(height: 10),
                          const _DataItemCard(
                            icon: Icons.location_on_outlined,
                            title: 'Location Data',
                            subtitle: 'Approximate location for service delivery',
                          ),
                          const SizedBox(height: 24),
                          const _SectionTitle('Purpose of processing'),
                          const SizedBox(height: 12),
                          const Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _PurposeChip('Account management'),
                              _PurposeChip('Service personalisation'),
                              _PurposeChip('Customer support'),
                              _PurposeChip('Legal compliance'),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const _SectionTitle('Your rights as a Data Principal'),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(
                                child: _RightItem(
                                  icon: Icons.visibility_outlined,
                                  label: 'Right to access',
                                ),
                              ),
                              Expanded(
                                child: _RightItem(
                                  icon: Icons.edit_outlined,
                                  label: 'Right to correction',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Row(
                            children: [
                              Expanded(
                                child: _RightItem(
                                  icon: Icons.delete_outline,
                                  label: 'Right to erasure',
                                ),
                              ),
                              Expanded(
                                child: _RightItem(
                                  icon: Icons.block_outlined,
                                  label: 'Right to withdraw',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: _Palette.cardBorder, height: 1),
                          const SizedBox(height: 16),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: _Palette.bodyGray,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                    text: 'For grievances, contact our '),
                                TextSpan(
                                  text: 'Grievance Officer',
                                  style: TextStyle(
                                    color: _Palette.link,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: ':'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'contact@asndtechnology.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: _Palette.bodyGray,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ConsentCheckboxRow(
                            value: _consentChecked,
                            onChanged: (v) =>
                                setState(() => _consentChecked = v ?? false),
                            child: const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _Palette.titleDark,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                      text:
                                      'I have read and understood how my data will be used. I give my '),
                                  TextSpan(
                                    text:
                                    'free, specific, informed, unconditional, and unambiguous',
                                    style:
                                    TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: ' consent.'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ConsentCheckboxRow(
                            value: _ageChecked,
                            onChanged: (v) =>
                                setState(() => _ageChecked = v ?? false),
                            child: const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _Palette.titleDark,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(text: 'I confirm I am 18 years or older. '),
                                  TextSpan(
                                    text:
                                    '(For minors, parental/guardian consent is required.)',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: _Palette.bodyGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _ConsentButton(
              enabled: _canSubmit,
              onPressed: _canSubmit ? _handleSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Palette.headerTop, _Palette.headerBottom],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ASND Technology Private Limited',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Data Privacy Consent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info banner
// ---------------------------------------------------------------------------
class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.banner,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: _Palette.bannerAccent, width: 4),
        ),
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 14.5,
            color: _Palette.titleDark,
            height: 1.5,
          ),
          children: [
            TextSpan(text: 'Under the '),
            TextSpan(
              text: 'Digital Personal Data Protection Act, 2023',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
                text:
                ', we are required to obtain your informed consent before processing your personal data.'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: _Palette.titleDark,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data collected card
// ---------------------------------------------------------------------------
class _DataItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _DataItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _Palette.iconGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _Palette.titleDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: _Palette.bodyGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Purpose chip
// ---------------------------------------------------------------------------
class _PurposeChip extends StatelessWidget {
  final String label;
  const _PurposeChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _Palette.chipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          color: _Palette.chipText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rights item
// ---------------------------------------------------------------------------
class _RightItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RightItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _Palette.iconGreen, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: _Palette.titleDark,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Checkbox row
// ---------------------------------------------------------------------------
class _ConsentCheckboxRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget child;

  const _ConsentCheckboxRow({
    required this.value,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: Color(0xFFBFBFBD), width: 1.4),
                activeColor: _Palette.buttonGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom "Give consent" button with floating scroll-down indicator
// ---------------------------------------------------------------------------
class _ConsentButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onPressed;

  const _ConsentButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Palette.buttonGreen,
                  disabledBackgroundColor:
                  _Palette.buttonGreen.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Give Consent',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}







// class DpdcaScreen extends StatefulWidget {
//   const DpdcaScreen({super.key});
//
//   @override
//   State<DpdcaScreen> createState() => _DpdcaScreenState();
// }
//
// class _DpdcaScreenState extends State<DpdcaScreen> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }
