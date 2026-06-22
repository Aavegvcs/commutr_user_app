/// Response for `GET /AppControl/GetAppControlSettingsByLocCode/{locCode}`.
///
/// Controls per-location feature visibility on the home screen:
///   - [adhocRequestEnabledForUser] gates the "ADHOC Request" drawer item.
///   - [boardDebaordEnabledForUser] gates the "Board / Deboard" action on the
///     active trip card.
class AppControlSettings {
  final bool adhocRequestEnabledForUser;
  final bool boardDebaordEnabledForUser;

  const AppControlSettings({
    required this.adhocRequestEnabledForUser,
    required this.boardDebaordEnabledForUser,
  });

  factory AppControlSettings.fromJson(Map<String, dynamic> json) {
    return AppControlSettings(
      adhocRequestEnabledForUser:
          json['adhocRequestEnabledForUser'] as bool? ?? false,
      boardDebaordEnabledForUser:
          json['boardDebaordEnabledForUser'] as bool? ?? false,
    );
  }
}
