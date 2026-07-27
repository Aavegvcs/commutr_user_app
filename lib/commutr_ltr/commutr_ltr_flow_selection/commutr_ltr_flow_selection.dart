import 'package:commutr_main/commutr_ltr/scan_qr/scan_qr.dart';
import 'package:flutter/material.dart';

/// Brand colors
const Color kCommutrDark = Color(0xFF1A2B2B);
const Color kCommutrGreen = Color(0xFF006C49);
const Color kCommutrDot = Color(0xFF1B7A4C);

class CommutrSelectionScreen extends StatelessWidget {
  const CommutrSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            _buildLogoBar(),
            const Spacer(flex: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  _PillButton(
                    label: 'For Single Trip',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScanQr(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 21),
                  _PillButton(
                    label: 'For Multiple trips',
                    onTap: () {
                      // TODO: navigate to multiple trips flow
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 9),
          ],
        ),
      ),
    );
  }
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
              Image.asset(
                'assets/images/app_logo.png',
                width: 136,
                height: 25,
                fit: BoxFit.cover,
              )
            ],
          ),
        ],
      ),
    ),
  );
}

/// Rounded green pill button used for both options
class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kCommutrGreen,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

