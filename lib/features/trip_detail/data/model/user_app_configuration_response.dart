/// Response for
/// `GET /UserAppConfiguration/GetUserAppConfigurationByLocCode?locCode={locCode}`.
///
/// The API returns the payload as a JSON *string* under a `result` key, e.g.
/// ```json
/// { "result": "{\"AppScheduleUiConfig\":{...},\"AppTripUiConfig\":{...}}" }
/// ```
/// so the repository decodes `result` before building this model.
///
/// Controls per-location UI gating for schedule and trip actions on the home
/// screen (Cancel / Edit / Track / Chat / Share cab / IVR call buttons, etc.).
class UserAppConfiguration {
  final AppScheduleUiConfig scheduleUiConfig;
  final AppTripUiConfig tripUiConfig;
  final CommonUiConfig commonUiConfig;

  const UserAppConfiguration({
    required this.scheduleUiConfig,
    required this.tripUiConfig,
    required this.commonUiConfig,
  });

  factory UserAppConfiguration.fromJson(Map<String, dynamic> json) {
    return UserAppConfiguration(
      scheduleUiConfig: AppScheduleUiConfig.fromJson(
        (json['AppScheduleUiConfig'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      tripUiConfig: AppTripUiConfig.fromJson(
        (json['AppTripUiConfig'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      commonUiConfig: CommonUiConfig.fromJson(
        (json['CommonUiConfig'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
    );
  }
}

/// Schedule-related UI gating flags.
class AppScheduleUiConfig {
  final bool isCancellationScheduledAllowed;
  final bool isEditScheduleAllowed;
  final bool isAlreadyScheduledNoShow;
  final bool isCancelledScheduledAllowedAfterTAT;
  final bool isTrackingScheduledAllowed;
  final bool isCreateScheduleAllowed;

  const AppScheduleUiConfig({
    required this.isCancellationScheduledAllowed,
    required this.isEditScheduleAllowed,
    required this.isAlreadyScheduledNoShow,
    required this.isCancelledScheduledAllowedAfterTAT,
    required this.isTrackingScheduledAllowed,
    required this.isCreateScheduleAllowed,
  });

  factory AppScheduleUiConfig.fromJson(Map<String, dynamic> json) {
    return AppScheduleUiConfig(
      isCancellationScheduledAllowed:
          json['isCancellationScheduledAllowed'] as bool? ?? false,
      isEditScheduleAllowed: json['isEditScheduleAllowed'] as bool? ?? false,
      isAlreadyScheduledNoShow:
          json['isAlreadyScheduledNoShow'] as bool? ?? false,
      isCancelledScheduledAllowedAfterTAT:
          json['isCancelledScheduledAllowedAfterTAT'] as bool? ?? false,
      isTrackingScheduledAllowed:
          json['isTrackingScheduledAllowed'] as bool? ?? false,
      // NOTE: API sends this key PascalCased ("IsCreateScheduleAllowed");
      // accept both casings defensively.
      isCreateScheduleAllowed: (json['IsCreateScheduleAllowed'] ??
              json['isCreateScheduleAllowed']) as bool? ??
          false,
    );
  }
}

/// Active-trip-related UI gating flags.
class AppTripUiConfig {
  final bool isTripTrackingAllowed;
  final bool isTripChatAllowed;
  final bool isTripShareCabAllowed;
  final bool isTripIvrCallAllowed;
  final bool isTripSafeHomeReach;
  final bool isTripCancellationAllowed;
  final bool isTripNoShowAllowed;
  final bool isDeboardOtpFieldAllowed;
  final bool isTripSummaryAllowed;

  const AppTripUiConfig({
    required this.isTripTrackingAllowed,
    required this.isTripChatAllowed,
    required this.isTripShareCabAllowed,
    required this.isTripIvrCallAllowed,
    required this.isTripSafeHomeReach,
    required this.isTripCancellationAllowed,
    required this.isTripNoShowAllowed,
    required this.isDeboardOtpFieldAllowed,
    required this.isTripSummaryAllowed,
  });

  factory AppTripUiConfig.fromJson(Map<String, dynamic> json) {
    return AppTripUiConfig(
      isTripTrackingAllowed: json['isTripTrackingAllowed'] as bool? ?? false,
      isTripChatAllowed: json['isTripChatAllowed'] as bool? ?? false,
      isTripShareCabAllowed: json['isTripShareCabAllowed'] as bool? ?? false,
      isTripIvrCallAllowed: json['isTripIvrCallAllowed'] as bool? ?? false,
      isTripSafeHomeReach: json['isTripSafeHomeReach'] as bool? ?? false,
      isTripCancellationAllowed:
          json['isTripCancellationAllowed'] as bool? ?? false,
      isTripNoShowAllowed: json['isTripNoShowAllowed'] as bool? ?? false,
      isDeboardOtpFieldAllowed:
          json['isDeboardOtpFieldAllowed'] as bool? ?? false,
      isTripSummaryAllowed: json['isTripSummaryAllowed'] as bool? ?? false,
    );
  }
}

/// Common (non trip/schedule specific) UI gating flags.
class CommonUiConfig {
  final bool isUserUpdateProfile;

  /// Backend-selected launcher icon campaign, e.g. `"default"` or
  /// `"independence_day"`.
  ///
  /// Deliberately a raw [String] rather than an enum: this model is a plain
  /// DTO and must not depend on the icon layer. Mapping to a concrete icon —
  /// and ignoring campaigns the installed build has no assets for — is
  /// `DynamicAppIconConfigMapper`'s job.
  ///
  /// `null` when the key is absent, which means "no instruction" — the app
  /// leaves the current icon alone. That keeps a partial or older payload from
  /// silently resetting a live campaign icon.
  final String? appIcon;

  const CommonUiConfig({
    required this.isUserUpdateProfile,
    this.appIcon,
  });

  factory CommonUiConfig.fromJson(Map<String, dynamic> json) {
    // Key casing is accepted both ways, matching how this file already handles
    // `IsCreateScheduleAllowed`. The backend has not shipped this field yet,
    // so its final casing is not settled.
    final rawAppIcon = json['AppIcon'] ?? json['appIcon'];

    return CommonUiConfig(
      isUserUpdateProfile: json['IsUserUpdateProfile'] as bool? ?? false,
      // Guard the cast: a non-string (number, bool, object) must not throw and
      // take the whole config parse down with it.
      appIcon: rawAppIcon is String && rawAppIcon.trim().isNotEmpty
          ? rawAppIcon.trim()
          : null,
    );
  }
}