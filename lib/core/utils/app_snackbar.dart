import 'package:flutter/material.dart';

enum _SnackType { success, error, warning }

class AppSnackbar {
  AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, _SnackType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, _SnackType.error);

  static void warning(BuildContext context, String message) =>
      _show(context, message, _SnackType.warning);

  static void _show(BuildContext context, String message, _SnackType type) {
    final (icon, bg, fg) = switch (type) {
      _SnackType.success => (
          Icons.check_circle_rounded,
          const Color(0xFF1A6B3C),
          Colors.white,
        ),
      _SnackType.error => (
          Icons.error_rounded,
          const Color(0xFFBA1A1A),
          Colors.white,
        ),
      _SnackType.warning => (
          Icons.warning_rounded,
          const Color(0xFFF59E0B),
          Colors.white,
        ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: bg.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
