/// The launcher icons this app ships.
///
/// Each value maps 1:1 to an `<activity-alias>` in
/// `android/app/src/main/AndroidManifest.xml`. The alias name is always
/// `<applicationId>.MainActivity.<aliasSuffix>` — see [aliasSuffix].
///
/// ## Adding a new icon (e.g. Diwali)
///
/// 1. Add the icon resource, e.g. `@mipmap/ic_diwali_logo`, in every
///    `mipmap-*` density bucket plus `mipmap-anydpi-v26`.
/// 2. Add an `<activity-alias>` named
///    `com.user.asnd.commutr.MainActivity.diwali` pointing at
///    `.MainActivity`, with `android:enabled="false"`.
/// 3. Add one enum value here.
/// 4. Add one line to [aliasSuffix].
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
