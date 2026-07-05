// =============================================================================
// Shorebird OTA Update — High-level Manager (orchestration + restart signal)
// =============================================================================
//
// Optional convenience layer on top of [ShorebirdUpdateService] for the common
// "check → download → ask user to restart" flow.
//
// It is intentionally UI-agnostic: instead of showing dialogs itself, it
// exposes a [restartRequired] stream/notifier that any widget can listen to and
// react however it wants (snackbar, dialog, banner…). This keeps the module
// pure plug-and-play and avoids coupling to the existing navigation / dialog
// code.
//
// Nothing here touches the existing version-check or store-update flow.
// =============================================================================

import 'package:flutter/foundation.dart';

import 'data/shorebird_update_service.dart';
import 'domain/i_shorebird_update_service.dart';
import 'domain/shorebird_update_models.dart';

/// Orchestrates the full OTA lifecycle and broadcasts when a restart is needed.
///
/// Usage (e.g. fire-and-forget after app start, off the critical path):
/// ```dart
/// final manager = ShorebirdUpdateManager();
/// manager.restartRequired.addListener(() {
///   if (manager.restartRequired.value) {
///     // show a non-blocking "Restart to apply update" prompt
///   }
/// });
/// // Do NOT await on the startup critical path — let it run in the background.
/// unawaited(manager.checkAndDownload());
/// ```
class ShorebirdUpdateManager {
  /// Creates the manager.
  ///
  /// [service] is injectable for testing; defaults to the production
  /// [ShorebirdUpdateService].
  ShorebirdUpdateManager({IShorebirdUpdateService? service})
      : _service = service ?? ShorebirdUpdateService();

  static const String _tag = '[SHOREBIRD_MGR]';

  final IShorebirdUpdateService _service;

  /// Broadcasts `true` the moment a patch has been downloaded and the app must
  /// be restarted to apply it. Listen to this to surface a restart prompt.
  ///
  /// It is a [ValueNotifier] so it integrates cleanly with widgets via
  /// `ValueListenableBuilder` without any extra dependencies.
  final ValueNotifier<bool> restartRequired = ValueNotifier<bool>(false);

  void _log(String message) => debugPrint('$_tag $message');

  /// Whether OTA updates are available in this build.
  bool get isAvailable => _service.isAvailable;

  /// Exposes the underlying service for callers that need fine-grained control
  /// (e.g. checking without downloading).
  IShorebirdUpdateService get service => _service;

  /// Convenience: check for an update only.
  Future<ShorebirdCheckResult> check({
    UpdateChannel channel = UpdateChannel.stable,
  }) {
    return _service.checkForUpdate(channel: channel);
  }

  /// Convenience: download a staged update only.
  Future<ShorebirdDownloadResult> download({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    final result = await _service.downloadUpdate(channel: channel);
    if (result.needsRestart) _signalRestartRequired();
    return result;
  }

  /// Full flow: check for an update and, if one is available, download it.
  ///
  /// Returns the [ShorebirdDownloadResult] when a download was attempted, or
  /// `null` when there was nothing to download / the updater is unavailable.
  /// On a successful download it flips [restartRequired] to `true`.
  ///
  /// This never throws and is safe to call from anywhere, including
  /// fire-and-forget at app start (do NOT block startup on it).
  Future<ShorebirdDownloadResult?> checkAndDownload({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    if (!_service.isAvailable) {
      _log('checkAndDownload: updater unavailable — skipping.');
      return null;
    }

    final check = await _service.checkForUpdate(channel: channel);
    _log('checkAndDownload: check status = ${check.status.name}');

    switch (check.status) {
      case ShorebirdCheckStatus.restartRequired:
        // A patch was already downloaded in a previous session.
        _signalRestartRequired();
        return null;

      case ShorebirdCheckStatus.updateAvailable:
        final download = await _service.downloadUpdate(channel: channel);
        if (download.needsRestart) {
          _signalRestartRequired();
        } else {
          _log('checkAndDownload: download did not complete '
              '— status = ${download.status.name}, error = ${download.error}');
        }
        return download;

      case ShorebirdCheckStatus.upToDate:
      case ShorebirdCheckStatus.unavailable:
      case ShorebirdCheckStatus.error:
        return null;
    }
  }

  void _signalRestartRequired() {
    if (!restartRequired.value) {
      _log('restart required — broadcasting to listeners.');
      restartRequired.value = true;
    }
  }

  /// Releases the [restartRequired] notifier. Call when the owning object that
  /// created this manager is disposed (no-op-safe if you keep it app-global).
  void dispose() => restartRequired.dispose();
}
