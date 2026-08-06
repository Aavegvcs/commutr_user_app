/// The launcher icons this app ships.
///
/// Each value uses ONE identifier across both platforms — see [aliasSuffix]:
///
/// * Android: an `<activity-alias>` named
///   `<applicationId>.MainActivity.<aliasSuffix>` in `AndroidManifest.xml`.
/// * iOS: a `CFBundleAlternateIcons` key equal to `<aliasSuffix>` in
///   `Info.plist`.
///
/// Keeping the identifiers identical is what lets the backend send a single
/// `appIcon` string that works on both platforms.
///
/// ## Adding a new icon (e.g. Diwali)
///
/// Android:
/// 1. Add `@mipmap/ic_diwali_logo` in every `mipmap-*` density bucket plus
///    `mipmap-anydpi-v26`.
/// 2. Add an `<activity-alias>` named
///    `com.user.asnd.commutr.MainActivity.diwali` pointing at `.MainActivity`,
///    with `android:enabled="false"`.
///
/// iOS — all four PNGs go in `ios/Runner/` (NOT `Assets.xcassets`) and must be
/// added to the target's "Copy Bundle Resources":
/// 3. iPhone: `AppIcon-diwali@2x.png` (120px), `AppIcon-diwali@3x.png` (180px).
/// 4. iPad: `AppIcon-diwali-ipad@2x.png` (152px) and
///    `AppIcon-diwali-ipad-pro@2x.png` (167px). iPad needs SEPARATE basenames —
///    a `~ipad` filename suffix is NOT resolved for `CFBundleIconFiles`, and
///    omitting these trips App Store validation warning 90892.
/// 5. `Info.plist`: `CFBundleIcons -> CFBundleAlternateIcons -> diwali` with
///    `CFBundleIconFiles = ["AppIcon-diwali"]`, and
///    `CFBundleIcons~ipad -> CFBundleAlternateIcons -> diwali` with
///    `["AppIcon-diwali-ipad", "AppIcon-diwali-ipad-pro"]`.
///
/// Dart:
/// 6. Add one enum value here.
/// 7. Add one line to [aliasSuffix].
///
/// Nothing else in the app needs to change — no screen, controller or BLoC
/// references icon identifiers directly.
enum DynamicAppIcon {
  /// The standard Commutr icon. Backed by the `MainActivity.default` alias.
  defaultIcon,

  /// Indian Independence Day campaign icon.
  independenceDay;

  /// The manifest alias suffix the plugin uses to identify this icon.
  ///
  /// `null` for [defaultIcon] — the plugin treats a null icon name as
  /// "restore the default alias", so it must never be given a literal
  /// `'default'` string.
  String? get aliasSuffix => switch (this) {
        DynamicAppIcon.defaultIcon => null,
        DynamicAppIcon.independenceDay => 'independence_day',
      };

  /// Resolves the alias suffix reported by the platform back into an enum
  /// value.
  ///
  /// The plugin returns `null` when the default alias is active. Any
  /// unrecognised value — for example an alias shipped by a newer build that
  /// this code does not know about — also resolves to [defaultIcon], because
  /// falling back to the standard icon is always safe.
  static DynamicAppIcon fromAliasSuffix(String? suffix) {
    if (suffix == null || suffix.isEmpty) return DynamicAppIcon.defaultIcon;

    for (final icon in DynamicAppIcon.values) {
      if (icon.aliasSuffix == suffix) return icon;
    }

    return DynamicAppIcon.defaultIcon;
  }
}
