// =============================================================================
// Shorebird OTA Update — Service Contract (Abstraction)
// =============================================================================
//
// Defines the public contract for the Shorebird OTA update module following
// the Dependency Inversion Principle: callers depend on this abstraction, not
// on the concrete implementation. This makes the service easy to mock in tests
// and swap out without touching call sites.
// =============================================================================

import 'shorebird_update_models.dart';

/// Abstraction over Shorebird over-the-air (OTA) patch updates.
///
/// Implementations must be safe to call on every platform and in every build
/// flavour: when the Shorebird engine is not present (debug builds,
/// `flutter run`, web, unsupported platforms) every method returns a benign
/// "unavailable" result instead of throwing.
abstract interface class IShorebirdUpdateService {
  /// Whether the Shorebird engine is present and OTA updates can run.
  ///
  /// Returns [ShorebirdAvailability.unavailable] in debug mode, when the app
  /// was not built with `shorebird release`, or on unsupported platforms.
  ShorebirdAvailability get availability;

  /// Convenience accessor — `true` only when [availability] is
  /// [ShorebirdAvailability.available].
  bool get isAvailable;

  /// Returns the currently active patch, or `null` if running the base release
  /// (or if the updater is unavailable).
  Future<ShorebirdPatchInfo?> currentPatch();

  /// Returns the most recently downloaded patch (the one that will be active
  /// after the next restart), or `null` if none / unavailable.
  Future<ShorebirdPatchInfo?> nextPatch();

  /// Checks whether an OTA update is available.
  ///
  /// Performs a network call. Returns a strongly-typed [ShorebirdCheckResult]
  /// and never throws — failures are reported via
  /// [ShorebirdCheckStatus.error].
  Future<ShorebirdCheckResult> checkForUpdate({UpdateChannel channel});

  /// Downloads (and stages) the latest available OTA patch.
  ///
  /// Performs a network call to download the patch. Returns a strongly-typed
  /// [ShorebirdDownloadResult] and never throws. On success a restart is
  /// required for the patch to take effect — see
  /// [ShorebirdDownloadResult.needsRestart].
  Future<ShorebirdDownloadResult> downloadUpdate({UpdateChannel channel});
}

/// App-facing release channel, decoupled from the package's `UpdateTrack` type
/// so callers don't import `shorebird_code_push` directly.
enum UpdateChannel {
  /// General availability — the default production track.
  stable,

  /// Public beta testing track.
  beta,

  /// Internal staging track.
  staging,
}
