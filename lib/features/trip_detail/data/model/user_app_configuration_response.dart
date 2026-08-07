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

  /// Whether the Area dropdown is offered when picking an address.
  final bool isAreaDdlEnabled;

  /// Whether the Zone dropdown is offered when picking an address.
  final bool isZoneDdlEnabled;

  /// Boarding verification mode selected for this location (e.g. OTP vs QR).
  /// Kept as a raw code — mapping it to a behaviour is the feature layer's job.
  final int? boardingType;

  /// De-boarding counterpart of [boardingType].
  final int? deboardingType;

  /// [boardingType] code for QR-based boarding: the passenger scans the cab's
  /// QR instead of reading out a Boarding/Deboard OTP, so no OTP field and no
  /// Board/Deboard CTA apply — a "Scan QR" action replaces them.
  static const int boardingTypeQr = 3;

  const CommonUiConfig({
    required this.isUserUpdateProfile,
    this.appIcon,
    this.isAreaDdlEnabled = false,
    this.isZoneDdlEnabled = false,
    this.boardingType,
    this.deboardingType,
  });

  /// Whether this location boards by QR scan rather than OTP. `false` when the
  /// field is absent (`null`), which keeps the existing OTP behaviour.
  bool get isQrBoarding => boardingType == boardingTypeQr;

  factory CommonUiConfig.fromJson(Map<String, dynamic> json) {
    // Key casing is accepted both ways, matching how this file already handles
    // `IsCreateScheduleAllowed`. The backend has not shipped this field yet,
    // so its final casing is not settled.
    final rawAppIcon = json['AppIcon'] ?? json['appIcon'];

    bool readBool(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final lower = v.toLowerCase();
        return lower == 'true' || lower == '1';
      }
      return false;
    }

    int? readInt(Object? v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    return CommonUiConfig(
      isUserUpdateProfile: json['IsUserUpdateProfile'] as bool? ?? false,
      // Guard the cast: a non-string (number, bool, object) must not throw and
      // take the whole config parse down with it.
      appIcon: rawAppIcon is String && rawAppIcon.trim().isNotEmpty
          ? rawAppIcon.trim()
          : null,
      isAreaDdlEnabled:
          readBool(json['IsAreaDDLEnabled'] ?? json['isAreaDDLEnabled']),
      // NOTE: the backend spells the zone key with a lowercase "l"
      // ("IsZoneDDlEnabled"); all three plausible casings are accepted so a
      // later spelling fix on the server does not silently disable the field.
      isZoneDdlEnabled: readBool(json['IsZoneDDlEnabled'] ??
          json['IsZoneDDLEnabled'] ??
          json['isZoneDDlEnabled']),
      boardingType: readInt(json['BoardingType'] ?? json['boardingType']),
      deboardingType: readInt(json['DeboardingType'] ?? json['deboardingType']),
    );
  }
}
