import 'package:flutter/foundation.dart';

import 'dynamic_app_icon.dart';
import 'dynamic_app_icon_service.dart';

/// Debug-only harness for exercising [DynamicAppIconService] by hand.
///
/// Intentionally has no UI — there is no test button in the production app.
/// Call these from a debugger console, a temporary throwaway call site, or a
/// dev-only screen. Every method is a no-op in release builds.
///
/// Typical manual verification, matching the launcher-behaviour test plan:
///
/// ```dart
/// await DynamicAppIconDebug.printDiagnostics();
/// await DynamicAppIconDebug.switchToIndependenceDay(); // then press Home
/// await DynamicAppIconDebug.restoreDefault();          // then press Home
/// ```
///
/// Because swaps are deferred by default to avoid OEM launchers kicking the
/// user to the home screen, these helpers apply the change immediately
/// ([DynamicAppIconService.applyPendingIcon]) so the effect is observable
/// without having to background the app first.
abstract final class DynamicAppIconDebug {
  static final DynamicAppIconService _service = DynamicAppIconService();

  static const String _tag = '[DYNAMIC_ICON_DEBUG]';

  /// Logs support status, available aliases and the active icon.
  static Future<void> printDiagnostics() async {
    if (!kDebugMode) return;

    final supported = await _service.isSupported();
    debugPrint('$_tag Dynamic icon supported: $supported');

    final available = await _service.getAvailableIcons();
    debugPrint('$_tag Available icons: $available');

    final current = await _service.getCurrentIcon();
    debugPrint('$_tag Current icon: ${current.name}');
  }

  /// Test 1 — switch default -> independence_day.
  static Future<void> switchToIndependenceDay() =>
      _apply(DynamicAppIcon.independenceDay);

  /// Test 2 — switch independence_day -> default.
  static Future<void> restoreDefault() => _apply(DynamicAppIcon.defaultIcon);

  static Future<void> _apply(DynamicAppIcon icon) async {
    if (!kDebugMode) return;

    await printDiagnostics();

    final label = icon == DynamicAppIcon.defaultIcon
        ? 'Restoring default icon'
        : 'Changing icon to ${icon.aliasSuffix}';
    debugPrint('$_tag $label');

    // deferUntilBackground: false so the swap is observable right away during
    // a manual test. Production callers should keep the safer default.
    final ok = await _service.setIcon(icon, deferUntilBackground: false);

    // Flush anything a previous deferred call left queued.
    await _service.applyPendingIcon();

    if (!ok) {
      debugPrint('$_tag Icon change FAILED — see errors above.');
      return;
    }

    debugPrint(
      icon == DynamicAppIcon.defaultIcon
          ? '$_tag Default icon restored'
          : '$_tag Icon changed successfully',
    );

    final current = await _service.getCurrentIcon();
    debugPrint('$_tag Verified current icon: ${current.name}');
  }
}
