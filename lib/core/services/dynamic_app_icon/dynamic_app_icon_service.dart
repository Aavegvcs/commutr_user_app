import 'dart:io';

import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';

import 'dynamic_app_icon.dart';

/// Switches the app's launcher icon.
///
/// This is the ONLY place in the Flutter codebase that may import
/// `dynamic_app_icon_flutter_plus`. Widgets, screens, BLoCs, repositories,
/// API services and notification handlers must go through this service so the
/// plugin stays swappable and every call site inherits the error containment
/// below.
///
/// ## How this works on Android
///
/// The manifest declares one `<activity-alias>` per icon, all targeting the
/// single real `.MainActivity`:
///
/// ```
/// com.user.asnd.commutr.MainActivity.default            -> @mipmap/ic_launcher
/// com.user.asnd.commutr.MainActivity.independence_day   -> @mipmap/ic_independence_day_logo
/// ```
///
/// The plugin calls `PackageManager.setComponentEnabledSetting()` to enable
/// exactly one alias and disable the rest. The launcher notices the resulting
/// package-change broadcast and redraws the icon. An alias is only an
/// alternative *name* for the same activity, so `MainActivity` itself is never
/// disabled — FCM, SignalR, Google Maps, the live-trip foreground service and
/// app startup are all unaffected by an icon swap.
///
/// ## Error containment
///
/// A launcher icon is decorative. Nothing here is allowed to break the app, so
/// every public method catches its own failures, logs them, and returns a safe
/// fallback instead of rethrowing. Callers do not need try/catch.
class DynamicAppIconService {
  DynamicAppIconService();

  static const String _logTag = '[DYNAMIC_ICON]';

  /// Whether this platform can switch launcher icons at all.
  ///
  /// Only Android is wired up in this app — the iOS side of the plugin needs
  /// `CFBundleAlternateIcons` entries in `Info.plist`, which have not been
  /// added. Returning `false` early keeps [setIcon] from attempting a swap that
  /// would always fail on iOS.
  Future<bool> isSupported() async {
    if (!Platform.isAndroid) {
      _log('Unsupported platform (${Platform.operatingSystem}).');
      return false;
    }

    try {
      return await DynamicAppIconFlutterPlus.supportsAlternateIcons;
    } catch (error, stackTrace) {
      _logError('Failed to read supportsAlternateIcons', error, stackTrace);
      return false;
    }
  }

  /// The alternate icon alias suffixes the installed build actually ships.
  ///
  /// Discovered from the manifest at runtime by the plugin. Note this
  /// deliberately excludes `default`, which is not an "alternate" icon.
  /// Returns an empty list on failure.
  Future<List<String>> getAvailableIcons() async {
    if (!Platform.isAndroid) return const [];

    try {
      return await DynamicAppIconFlutterPlus.getAvailableIcons();
    } catch (error, stackTrace) {
      _logError('Failed to read available icons', error, stackTrace);
      return const [];
    }
  }

  /// The icon currently shown in the launcher.
  ///
  /// Falls back to [DynamicAppIcon.defaultIcon] whenever the real value cannot
  /// be determined, since that is what a fresh install shows.
  Future<DynamicAppIcon> getCurrentIcon() async {
    if (!Platform.isAndroid) return DynamicAppIcon.defaultIcon;

    try {
      final suffix = await DynamicAppIconFlutterPlus.getAlternateIconName();
      return DynamicAppIcon.fromAliasSuffix(suffix);
    } catch (error, stackTrace) {
      _logError('Failed to read current icon', error, stackTrace);
      return DynamicAppIcon.defaultIcon;
    }
  }

  /// Switches the launcher icon to [icon].
  ///
  /// Returns `true` when the icon was applied (or was already active), `false`
  /// when the swap was skipped or failed. Never throws.
  ///
  /// [deferUntilBackground] queues the swap instead of applying it
  /// immediately, and it defaults to `true` on purpose. Several OEM launchers
  /// (MIUI, EMUI, OneUI, ColorOS) react to the package-change broadcast by
  /// refreshing the home screen, which kicks the user out of the foreground
  /// app mid-session. Deferring avoids that; see [applyPendingIcon].
  Future<bool> setIcon(
    DynamicAppIcon icon, {
    bool deferUntilBackground = true,
  }) async {
    if (!await isSupported()) {
      _log('Skipping switch to ${icon.name} — alternate icons unsupported.');
      return false;
    }

    final targetSuffix = icon.aliasSuffix;

    // Validate against what the installed build actually ships. Requesting an
    // alias that is not in the manifest makes the plugin throw
    // IllegalArgumentException, which surfaces as a PlatformException. This
    // matters for backend-driven icons later: the server may name a campaign
    // this build has no assets for, and that must be a no-op, not a crash.
    if (targetSuffix != null) {
      final available = await getAvailableIcons();
      if (!available.contains(targetSuffix)) {
        _log(
          "Skipping switch to '$targetSuffix' — not available in this build. "
          'Available: $available',
        );
        return false;
      }
    }

    try {
      final current = await getCurrentIcon();
      if (current == icon) {
        _log('Icon is already ${icon.name} — nothing to do.');
        return true;
      }

      _log('Changing icon: ${current.name} -> ${icon.name}');

      await DynamicAppIconFlutterPlus.setAlternateIconName(
        targetSuffix,
        deferUntilBackground: deferUntilBackground,
      );

      _log(
        deferUntilBackground
            ? 'Icon change to ${icon.name} queued; applies on background.'
            : 'Icon changed to ${icon.name} successfully.',
      );
      return true;
    } catch (error, stackTrace) {
      _logError('Failed to change icon to ${icon.name}', error, stackTrace);
      return false;
    }
  }

  /// Restores the standard Commutr icon.
  Future<bool> restoreDefault({bool deferUntilBackground = true}) {
    return setIcon(
      DynamicAppIcon.defaultIcon,
      deferUntilBackground: deferUntilBackground,
    );
  }

  /// Applies an icon change queued by [setIcon].
  ///
  /// Call this when the app moves to the background
  /// ([AppLifecycleState.paused]) so a deferred swap lands the moment the user
  /// leaves the app, rather than waiting for the process to be torn down.
  /// A no-op when nothing is pending, and on iOS.
  Future<void> applyPendingIcon() async {
    if (!Platform.isAndroid) return;

    try {
      await DynamicAppIconFlutterPlus.applyPendingIcon();
    } catch (error, stackTrace) {
      _logError('Failed to apply pending icon', error, stackTrace);
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('$_logTag $message');
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    // Always logged, including release, because a silently-failing icon swap
    // is otherwise invisible. debugPrint is the project-wide convention; there
    // is no crash-reporting sink wired up yet.
    debugPrint('$_logTag ERROR: $message -> $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace, label: _logTag);
  }
}
