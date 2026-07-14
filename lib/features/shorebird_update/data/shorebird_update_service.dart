// =============================================================================
// Shorebird OTA Update — Service Implementation
// =============================================================================
//
// Production-ready, plug-and-play wrapper around the latest (non-deprecated)
// `shorebird_code_push` v2.x API.
//
// Design notes
// ------------
// * SINGLE RESPONSIBILITY: this class does exactly one thing — orchestrate
//   Shorebird OTA patch checks/downloads and expose strongly-typed results.
// * DEPENDENCY INVERSION: depends on the [ShorebirdUpdater] abstraction from
//   the package and implements the app-level [IShorebirdUpdateService]
//   contract. The updater can be injected for testing.
// * FAIL-SAFE: every public method is wrapped in exhaustive exception handling
//   and NEVER throws to the caller. If the engine is unavailable the methods
//   are benign no-ops. This guarantees it can be dropped into any flow without
//   risking existing functionality.
// * NON-DEPRECATED API ONLY: uses `ShorebirdUpdater().isAvailable`,
//   `checkForUpdate()`, `update()`, `readCurrentPatch()`, `readNextPatch()`.
//   It does NOT use the legacy `ShorebirdCodePush`/`isNewPatchAvailableFor
//   Download`/`downloadUpdate` APIs (removed/deprecated in v2.x).
// * PLATFORM: works on Android and iOS. On web / unsupported platforms the
//   package reports `isAvailable == false`, so all calls degrade gracefully.
//
// This module is completely independent of the existing version-check / Play
// Store / App Store update flow and does not modify any existing code.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../domain/i_shorebird_update_service.dart';
import '../domain/shorebird_update_models.dart';

/// Concrete [IShorebirdUpdateService] backed by `shorebird_code_push`.
class ShorebirdUpdateService implements IShorebirdUpdateService {
  /// Creates the service.
  ///
  /// [updater] is injectable purely for testing; in production the default
  /// [ShorebirdUpdater] is used.
  ShorebirdUpdateService({ShorebirdUpdater? updater})
      : _updater = updater ?? (_shorebirdEngineExpected ? ShorebirdUpdater() : null);

  /// Log tag, consistent with the rest of the codebase (e.g. `[VERSION_CHECK]`).
  static const String _tag = '[SHOREBIRD]';

  /// Whether the Shorebird engine can possibly be present in this build.
  ///
  /// Shorebird only embeds its engine in `shorebird release`/`shorebird preview`
  /// builds, which are release-mode. In debug/profile (`flutter run`) the engine
  /// is never present, so we skip instantiating [ShorebirdUpdater] entirely —
  /// this avoids the native "Shorebird Updater is unavailable…" console notice
  /// during development. In release mode we still instantiate normally, so real
  /// Shorebird release builds behave exactly as before.
  static bool get _shorebirdEngineExpected => kReleaseMode;

  /// The underlying Shorebird updater (latest non-deprecated API surface).
  ///
  /// `null` when the engine cannot be present in this build (debug/profile), in
  /// which case every method degrades to a benign no-op — identical behaviour to
  /// `isAvailable == false`.
  final ShorebirdUpdater? _updater;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Centralised debug logging. Routed through [debugPrint] so it is stripped
  /// in release builds and rate-limited by the framework.
  void _log(String message) => debugPrint('$_tag $message');

  /// Maps the app-level [UpdateChannel] to the package's `UpdateTrack`.
  UpdateTrack _trackFor(UpdateChannel channel) {
    switch (channel) {
      case UpdateChannel.stable:
        return UpdateTrack.stable;
      case UpdateChannel.beta:
        return UpdateTrack.beta;
      case UpdateChannel.staging:
        return UpdateTrack.staging;
    }
  }

  // ---------------------------------------------------------------------------
  // Availability
  // ---------------------------------------------------------------------------

  @override
  ShorebirdAvailability get availability {
    return isAvailable
        ? ShorebirdAvailability.available
        : ShorebirdAvailability.unavailable;
  }

  @override
  bool get isAvailable => _updater?.isAvailable ?? false;

  // ---------------------------------------------------------------------------
  // Patch inspection
  // ---------------------------------------------------------------------------

  @override
  Future<ShorebirdPatchInfo?> currentPatch() async {
    if (!isAvailable) {
      _log('currentPatch: updater unavailable in this build — returning null.');
      return null;
    }
    try {
      final patch = await _updater!.readCurrentPatch();
      _log('currentPatch: ${patch?.number ?? 'none (base release)'}');
      return patch == null ? null : ShorebirdPatchInfo.fromPatch(patch);
    } on ReadPatchException catch (e) {
      _log('currentPatch: ReadPatchException — ${e.message}');
      return null;
    } catch (e, st) {
      _log('currentPatch: unexpected error — $e\n$st');
      return null;
    }
  }

  @override
  Future<ShorebirdPatchInfo?> nextPatch() async {
    if (!isAvailable) {
      _log('nextPatch: updater unavailable in this build — returning null.');
      return null;
    }
    try {
      final patch = await _updater!.readNextPatch();
      _log('nextPatch: ${patch?.number ?? 'none'}');
      return patch == null ? null : ShorebirdPatchInfo.fromPatch(patch);
    } on ReadPatchException catch (e) {
      _log('nextPatch: ReadPatchException — ${e.message}');
      return null;
    } catch (e, st) {
      _log('nextPatch: unexpected error — $e\n$st');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Check for OTA updates
  // ---------------------------------------------------------------------------

  @override
  Future<ShorebirdCheckResult> checkForUpdate({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    if (!isAvailable) {
      _log('checkForUpdate: updater unavailable — no-op.');
      return ShorebirdCheckResult.unavailable();
    }

    try {
      _log('checkForUpdate: checking on "${channel.name}" track…');

      // Read the active patch first so the result is fully populated for the
      // caller regardless of the check outcome.
      final current = await currentPatch();

      final status = await _updater!.checkForUpdate(track: _trackFor(channel));
      _log('checkForUpdate: status = ${status.name}');

      switch (status) {
        case UpdateStatus.upToDate:
          return ShorebirdCheckResult.upToDate(current);
        case UpdateStatus.outdated:
          return ShorebirdCheckResult.updateAvailable(current);
        case UpdateStatus.restartRequired:
          return ShorebirdCheckResult.restartRequired(current);
        case UpdateStatus.unavailable:
          return ShorebirdCheckResult.unavailable();
      }
    } catch (e, st) {
      _log('checkForUpdate: error — $e\n$st');
      return ShorebirdCheckResult.error(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Download OTA updates
  // ---------------------------------------------------------------------------

  @override
  Future<ShorebirdDownloadResult> downloadUpdate({
    UpdateChannel channel = UpdateChannel.stable,
  }) async {
    if (!isAvailable) {
      _log('downloadUpdate: updater unavailable — no-op.');
      return ShorebirdDownloadResult.unavailable();
    }

    try {
      _log('downloadUpdate: starting download on "${channel.name}" track…');

      // `update()` downloads + stages the patch and completes once it is ready
      // for the next app start. It throws an [UpdateException] when there is no
      // update available or when the download/install fails.
      await _updater!.update(track: _trackFor(channel));

      // After a successful update the newly-staged patch is the "next" patch.
      final staged = await nextPatch();
      _log('downloadUpdate: success — restart required '
          '(staged patch: ${staged?.number ?? 'unknown'}).');
      return ShorebirdDownloadResult.success(staged);
    } on UpdateException catch (e) {
      // Distinguish "nothing to download" from a genuine failure.
      if (e.reason == UpdateFailureReason.noUpdate) {
        _log('downloadUpdate: no update available — ${e.message}');
        return ShorebirdDownloadResult.noUpdate();
      }
      _log('downloadUpdate: failed (${e.reason.name}) — ${e.message}');
      return ShorebirdDownloadResult.failed(e.message, e.reason);
    } catch (e, st) {
      _log('downloadUpdate: unexpected error — $e\n$st');
      return ShorebirdDownloadResult.failed(
        e.toString(),
        UpdateFailureReason.unknown,
      );
    }
  }
}
