import 'dynamic_app_icon.dart';

/// Translates the backend's `appIcon` string into a [DynamicAppIcon].
///
/// This is the configuration layer that sits between the API model and
/// [DynamicAppIconService]:
///
/// ```
/// Backend -> UserAppConfiguration.commonUiConfig.appIcon (String?)
///         -> DynamicAppIconConfigMapper                  (this class)
///         -> DynamicAppIconService                       (enum in, plugin out)
///         -> Android launcher alias
/// ```
///
/// Keeping the string->enum mapping here means the service never parses
/// backend payloads and the DTO never imports the icon layer.
///
/// ## Adding a new campaign
///
/// Add the enum value + its `aliasSuffix` in [DynamicAppIcon] and it is
/// automatically understood here — [resolve] matches against
/// [DynamicAppIcon.values], so there is no second list to keep in sync.
abstract final class DynamicAppIconConfigMapper {
  /// The value the backend sends to mean "use the standard icon".
  ///
  /// [DynamicAppIcon.defaultIcon] has a `null` aliasSuffix (the plugin's
  /// restore-default signal), so it can't be matched by suffix and needs this
  /// explicit keyword.
  static const String defaultKeyword = 'default';

  /// Resolves a backend `appIcon` value.
  ///
  /// Returns `null` when there is nothing to do:
  /// * [raw] is `null`/blank — the field is absent, i.e. no instruction. The
  ///   caller must leave the current icon untouched rather than assume
  ///   "default", so an older or partial payload can't silently kill a live
  ///   campaign.
  /// * [raw] names a campaign this build has no assets for (e.g. the backend
  ///   rolls out `diwali` before the app update ships). Unknown values are
  ///   ignored, never treated as an error.
  ///
  /// Matching is case-insensitive and trims whitespace, since the value is
  /// typically typed into an admin console.
  static DynamicAppIcon? resolve(String? raw) {
    if (raw == null) return null;

    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (normalized == defaultKeyword) return DynamicAppIcon.defaultIcon;

    for (final icon in DynamicAppIcon.values) {
      if (icon.aliasSuffix?.toLowerCase() == normalized) return icon;
    }

    // Unknown campaign — this build predates it. Caller logs and no-ops.
    return null;
  }
}
