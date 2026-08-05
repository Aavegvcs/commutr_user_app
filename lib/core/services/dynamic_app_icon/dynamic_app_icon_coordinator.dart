import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'dynamic_app_icon.dart';
import 'dynamic_app_icon_config_mapper.dart';
import 'dynamic_app_icon_service.dart';

/// Applies the backend-configured launcher icon.
///
/// Owns the whole deferred-swap lifecycle so callers need one line and no
/// lifecycle bookkeeping:
///
/// ```dart
/// sl<DynamicAppIconCoordinator>()
///     .applyFromConfig(state.config.commonUiConfig.appIcon);
/// ```
///
/// ## Why the swap is deferred
///
/// Switching a launcher alias makes Android broadcast a package change. Several
/// OEM launchers (OneUI, MIUI, EMUI, ColorOS) respond by refreshing the home
/// screen, which ejects the user from the app they are using. So the swap is
/// queued and applied the moment the app is backgrounded — the icon still
/// updates promptly, but never mid-session.
///
/// This class registers a [WidgetsBindingObserver] only while a change is
/// actually pending, then removes it again.
///
/// ## Idempotency
///
/// [applyFromConfig] is safe to call repeatedly. The config API is re-fetched
/// on pull-to-refresh and on roster changes, so it will be. Requests that
/// match the last one are dropped without touching the platform, and
/// [DynamicAppIconService.setIcon] independently no-ops when the requested
/// icon is already active.
class DynamicAppIconCoordinator with WidgetsBindingObserver {
  DynamicAppIconCoordinator(this._service);

  final DynamicAppIconService _service;

  static const String _logTag = '[DYNAMIC_ICON_CONFIG]';

  /// The last icon handed to the platform, used to drop duplicate requests.
  DynamicAppIcon? _lastRequested;

  /// Whether a queued swap is waiting for the app to background.
  bool _hasPendingSwap = false;

  /// Whether this instance is currently subscribed to lifecycle events.
  bool _isObserving = false;

  /// Resolves [rawAppIcon] from the API and queues the swap.
  ///
  /// A `null`/blank value means the backend sent no instruction, so the current
  /// icon is left alone. An unrecognised campaign (assets not in this build) is
  /// logged and ignored. Never throws.
  Future<void> applyFromConfig(String? rawAppIcon) async {
    final icon = DynamicAppIconConfigMapper.resolve(rawAppIcon);

    if (icon == null) {
      if (rawAppIcon != null && rawAppIcon.trim().isNotEmpty) {
        _log(
          "Ignoring unknown appIcon '$rawAppIcon' — no assets in this build.",
        );
      }
      return;
    }

    if (_lastRequested == icon) return;
    _lastRequested = icon;

    _log("Backend requested appIcon '$rawAppIcon' -> ${icon.name}.");

    // deferUntilBackground: the swap is queued natively and applied when the
    // app leaves the foreground — see the class doc.
    final queued = await _service.setIcon(icon, deferUntilBackground: true);
    if (!queued) {
      // Unsupported device, unavailable alias, or a platform failure. The
      // service has already logged the reason. Clear the memo so a later
      // config refresh can retry.
      _lastRequested = null;
      return;
    }

    _hasPendingSwap = true;
    _startObserving();
  }

  /// Flushes a queued swap once the app is no longer in the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }
    if (!_hasPendingSwap) return;

    _hasPendingSwap = false;
    _log('App backgrounded — applying queued icon change.');

    // Fire-and-forget: the framework's lifecycle callback is synchronous, and
    // the service swallows and logs its own errors.
    _service.applyPendingIcon();

    _stopObserving();
  }

  void _startObserving() {
    if (_isObserving) return;
    WidgetsBinding.instance.addObserver(this);
    _isObserving = true;
  }

  void _stopObserving() {
    if (!_isObserving) return;
    WidgetsBinding.instance.removeObserver(this);
    _isObserving = false;
  }

  /// Releases the lifecycle subscription. Safe to call when not observing.
  void dispose() => _stopObserving();

  void _log(String message) {
    if (kDebugMode) debugPrint('$_logTag $message');
  }
}
