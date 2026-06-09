import 'package:flutter/foundation.dart';

/// Central, compile-time switch between LIVE and DUMMY tracking.
///
/// Production safety is guaranteed by construction:
///   * `kReleaseMode` forces LIVE in any release build — the dummy flag is
///     ignored entirely, so `flutter build apk --release` is always live.
///   * In debug/profile, dummy tracking activates ONLY when the run is started
///     with `--dart-define=DUMMY_TRACKING=true`.
///   * A plain `flutter run` (no dart-define) defaults to LIVE.
///
/// Nothing in this app *ever* flips to dummy at runtime — it is decided once,
/// at compile time, from the environment. The rest of the app reads
/// [TrackingConfig.useDummyTracking] and behaves identically for both modes.
class TrackingConfig {
  const TrackingConfig._();

  /// The raw dart-define, evaluated at compile time. Defaults to false.
  static const bool _dummyDefine =
      bool.fromEnvironment('DUMMY_TRACKING', defaultValue: false);

  /// True only in a non-release build that was explicitly started with
  /// `--dart-define=DUMMY_TRACKING=true`. Always false in release.
  static bool get useDummyTracking => !kReleaseMode && _dummyDefine;

  /// Convenience inverse.
  static bool get useLiveTracking => !useDummyTracking;
}
