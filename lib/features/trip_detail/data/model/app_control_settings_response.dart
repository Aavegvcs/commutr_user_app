/// Response for `GET /AppControl/GetAppControlSettingsByLocCode/{locCode}`.
///
/// Controls per-location feature visibility on the home screen:
///   - [adhocRequestEnabledForUser] gates the "ADHOC Request" drawer item.
///   - [boardDebaordEnabledForUser] gates the "Board / Deboard" action on the
///     active trip card.
///   - [hybridScheduleEnabled] gates hybrid schedule behavior.
class AppControlSettings {
  final bool adhocRequestEnabledForUser;
  final bool boardDebaordEnabledForUser;
  final bool hybridScheduleEnabled;

  const AppControlSettings({
    required this.adhocRequestEnabledForUser,
    required this.boardDebaordEnabledForUser,
    required this.hybridScheduleEnabled,
  });

  factory AppControlSettings.fromJson(Map<String, dynamic> json) {
    return AppControlSettings(
      adhocRequestEnabledForUser:
          json['adhocRequestEnabledForUser'] as bool? ?? false,
      boardDebaordEnabledForUser:
          json['boardDebaordEnabledForUser'] as bool? ?? false,
      hybridScheduleEnabled:
          json['hybridScheduleEnabled'] as bool? ?? false,
    );
  }
}
 