/// Response for `GET /AppControl/GetAppControlSettingsByLocCode/{locCode}`.
///
/// Controls per-location feature visibility on the home screen:
///   - [adhocRequestEnabledForUser] gates the "ADHOC Request" drawer item.
///   - [boardDebaordEnabledForUser] gates the "Board / Deboard" action on the
///     active trip card.
///   - [hybridScheduleEnabled] gates hybrid schedule behavior.
///   - [isScheduleFillForLoginAndLogoutBoth] indicates whether schedule fill
///     applies to both login and logout.
///   - [isBoardDeBoardOTPSameOrDifferent] indicates whether the board/deboard
///     OTP is the same or different.
class AppControlSettings {
  final bool adhocRequestEnabledForUser;
  final bool boardDebaordEnabledForUser;
  final bool hybridScheduleEnabled;
  final bool isScheduleFillForLoginAndLogoutBoth;
  final bool isBoardDeBoardOTPSameOrDifferent;

  const AppControlSettings({
    required this.adhocRequestEnabledForUser,
    required this.boardDebaordEnabledForUser,
    required this.hybridScheduleEnabled,
    required this.isScheduleFillForLoginAndLogoutBoth,
    required this.isBoardDeBoardOTPSameOrDifferent,
  });

  factory AppControlSettings.fromJson(Map<String, dynamic> json) {
    return AppControlSettings(
      adhocRequestEnabledForUser:
          json['adhocRequestEnabledForUser'] as bool? ?? false,
      boardDebaordEnabledForUser:
          json['boardDebaordEnabledForUser'] as bool? ?? false,
      hybridScheduleEnabled:
          json['hybridScheduleEnabled'] as bool? ?? false,
      isScheduleFillForLoginAndLogoutBoth:
          json['isScheduleFillForLoginAndLogoutBoth'] as bool? ?? false,
      isBoardDeBoardOTPSameOrDifferent:
          json['isBoardDeBoardOTPSameOrDifferent'] as bool? ?? false,
    );
  }
}
 