// =============================================================================
// Shorebird OTA Update — Domain Models
// =============================================================================
//
// Strongly-typed result objects returned by [ShorebirdUpdateService].
//
// These models exist so callers never have to interpret raw `bool`s or the
// low-level `shorebird_code_push` enums directly. Every public method on the
// service returns one of these immutable, self-describing value objects.
//
// This file has NO dependency on Flutter widgets or the rest of the app, so it
// can be reused / unit-tested in isolation.
// =============================================================================

import 'package:shorebird_code_push/shorebird_code_push.dart';

/// High-level availability of the Shorebird updater in the current build.
///
/// The updater is only available when the app was built with
/// `shorebird release` (release mode) and is running on a supported platform
/// (Android / iOS). In debug builds, `flutter run`, or on the web it is
/// unavailable — and every OTA operation becomes a safe no-op.
enum ShorebirdAvailability {
  /// The Shorebird engine is present and OTA updates can be performed.
  available,

  /// The Shorebird engine is not present (debug build, `flutter run`,
  /// unsupported platform, etc.). All OTA operations are no-ops.
  unavailable,
}

/// The outcome of [ShorebirdUpdateService.checkForUpdate].
enum ShorebirdCheckStatus {
  /// The app is running the latest available patch. Nothing to do.
  upToDate,

  /// A new patch is available to download (call `downloadUpdate`).
  updateAvailable,

  /// A patch has already been downloaded and the app must restart for it to
  /// take effect.
  restartRequired,

  /// The updater is not available in this build (no-op environment).
  unavailable,

  /// The check failed (e.g. network error). See [ShorebirdCheckResult.error].
  error,
}

/// The outcome of [ShorebirdUpdateService.downloadUpdate].
enum ShorebirdDownloadStatus {
  /// The patch was downloaded successfully and a restart is now required.
  success,

  /// There was no update available to download.
  noUpdate,

  /// The updater is not available in this build (no-op environment).
  unavailable,

  /// The download / install failed. See [ShorebirdDownloadResult.error] and
  /// [ShorebirdDownloadResult.failureReason].
  failed,
}

/// Immutable description of an installed / downloaded patch.
///
/// Wraps the package-level [Patch] so callers never depend on the
/// `shorebird_code_push` types directly.
class ShorebirdPatchInfo {
  const ShorebirdPatchInfo({required this.number});

  /// The monotonically increasing patch number.
  final int number;

  /// Builds a [ShorebirdPatchInfo] from the package [Patch], or `null` when
  /// no patch is present.
  factory ShorebirdPatchInfo.fromPatch(Patch patch) =>
      ShorebirdPatchInfo(number: patch.number);

  @override
  String toString() => 'ShorebirdPatchInfo(number: $number)';
}

/// Result of checking for an OTA update.
///
/// Strongly typed alternative to a raw `bool`. Inspect [status] to branch and,
/// when applicable, read [error] for diagnostics.
class ShorebirdCheckResult {
  const ShorebirdCheckResult({
    required this.status,
    this.currentPatch,
    this.error,
  });

  /// The high-level check outcome.
  final ShorebirdCheckStatus status;

  /// The currently installed patch, if any (may be `null` on the base release).
  final ShorebirdPatchInfo? currentPatch;

  /// A human-readable error message when [status] is
  /// [ShorebirdCheckStatus.error]; otherwise `null`.
  final String? error;

  /// `true` when a new patch is available to download.
  bool get hasUpdate => status == ShorebirdCheckStatus.updateAvailable;

  /// `true` when a downloaded patch is waiting for an app restart.
  bool get needsRestart => status == ShorebirdCheckStatus.restartRequired;

  // --- Convenience factories (keep call sites terse and explicit) ----------

  factory ShorebirdCheckResult.upToDate(ShorebirdPatchInfo? current) =>
      ShorebirdCheckResult(
        status: ShorebirdCheckStatus.upToDate,
        currentPatch: current,
      );

  factory ShorebirdCheckResult.updateAvailable(ShorebirdPatchInfo? current) =>
      ShorebirdCheckResult(
        status: ShorebirdCheckStatus.updateAvailable,
        currentPatch: current,
      );

  factory ShorebirdCheckResult.restartRequired(ShorebirdPatchInfo? current) =>
      ShorebirdCheckResult(
        status: ShorebirdCheckStatus.restartRequired,
        currentPatch: current,
      );

  factory ShorebirdCheckResult.unavailable() => const ShorebirdCheckResult(
        status: ShorebirdCheckStatus.unavailable,
      );

  factory ShorebirdCheckResult.error(String message) => ShorebirdCheckResult(
        status: ShorebirdCheckStatus.error,
        error: message,
      );

  @override
  String toString() =>
      'ShorebirdCheckResult(status: $status, currentPatch: $currentPatch, '
      'error: $error)';
}

/// Result of downloading an OTA update.
///
/// Strongly typed alternative to a raw `bool`. On success a restart is always
/// required; inspect [needsRestart].
class ShorebirdDownloadResult {
  const ShorebirdDownloadResult({
    required this.status,
    this.installedPatch,
    this.error,
    this.failureReason,
  });

  /// The high-level download outcome.
  final ShorebirdDownloadStatus status;

  /// The patch that was downloaded and is now pending a restart, if known.
  final ShorebirdPatchInfo? installedPatch;

  /// A human-readable error message when [status] is
  /// [ShorebirdDownloadStatus.failed]; otherwise `null`.
  final String? error;

  /// The package-level failure reason when [status] is
  /// [ShorebirdDownloadStatus.failed]; otherwise `null`.
  final UpdateFailureReason? failureReason;

  /// `true` when the download succeeded and the app must restart to apply it.
  bool get needsRestart => status == ShorebirdDownloadStatus.success;

  /// `true` when the download completed successfully.
  bool get isSuccess => status == ShorebirdDownloadStatus.success;

  // --- Convenience factories ------------------------------------------------

  factory ShorebirdDownloadResult.success(ShorebirdPatchInfo? patch) =>
      ShorebirdDownloadResult(
        status: ShorebirdDownloadStatus.success,
        installedPatch: patch,
      );

  factory ShorebirdDownloadResult.noUpdate() => const ShorebirdDownloadResult(
        status: ShorebirdDownloadStatus.noUpdate,
      );

  factory ShorebirdDownloadResult.unavailable() =>
      const ShorebirdDownloadResult(
        status: ShorebirdDownloadStatus.unavailable,
      );

  factory ShorebirdDownloadResult.failed(
    String message,
    UpdateFailureReason reason,
  ) =>
      ShorebirdDownloadResult(
        status: ShorebirdDownloadStatus.failed,
        error: message,
        failureReason: reason,
      );

  @override
  String toString() =>
      'ShorebirdDownloadResult(status: $status, installedPatch: '
      '$installedPatch, error: $error, failureReason: $failureReason)';
}
