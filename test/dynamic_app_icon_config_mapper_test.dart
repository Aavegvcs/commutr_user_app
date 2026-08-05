import 'package:commutr_main/core/services/dynamic_app_icon/dynamic_app_icon.dart';
import 'package:commutr_main/core/services/dynamic_app_icon/dynamic_app_icon_config_mapper.dart';
import 'package:commutr_main/features/trip_detail/data/model/user_app_configuration_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DynamicAppIconConfigMapper.resolve', () {
    test('maps the default keyword to defaultIcon', () {
      expect(
        DynamicAppIconConfigMapper.resolve('default'),
        DynamicAppIcon.defaultIcon,
      );
    });

    test('maps a known campaign to its enum value', () {
      expect(
        DynamicAppIconConfigMapper.resolve('independence_day'),
        DynamicAppIcon.independenceDay,
      );
    });

    test('is case-insensitive and trims admin-console whitespace', () {
      expect(
        DynamicAppIconConfigMapper.resolve('  Independence_Day  '),
        DynamicAppIcon.independenceDay,
      );
      expect(
        DynamicAppIconConfigMapper.resolve('DEFAULT'),
        DynamicAppIcon.defaultIcon,
      );
    });

    test('returns null for absent/blank input so the icon is left alone', () {
      expect(DynamicAppIconConfigMapper.resolve(null), isNull);
      expect(DynamicAppIconConfigMapper.resolve(''), isNull);
      expect(DynamicAppIconConfigMapper.resolve('   '), isNull);
    });

    test('returns null for a campaign this build has no assets for', () {
      // Backend rolls out `diwali` before the app update ships.
      expect(DynamicAppIconConfigMapper.resolve('diwali'), isNull);
      expect(DynamicAppIconConfigMapper.resolve('christmas'), isNull);
    });

    test('every enum value is resolvable from its own alias suffix', () {
      // Guards the "add one enum value + one mapping" contract: a new icon
      // must be reachable from the backend without touching the mapper.
      for (final icon in DynamicAppIcon.values) {
        final suffix = icon.aliasSuffix;
        if (suffix == null) continue; // defaultIcon uses the keyword instead
        expect(
          DynamicAppIconConfigMapper.resolve(suffix),
          icon,
          reason: 'alias "$suffix" should resolve back to ${icon.name}',
        );
      }
    });
  });

  group('CommonUiConfig.fromJson appIcon parsing', () {
    test('reads PascalCase key', () {
      final c = CommonUiConfig.fromJson({'AppIcon': 'independence_day'});
      expect(c.appIcon, 'independence_day');
    });

    test('reads camelCase key', () {
      final c = CommonUiConfig.fromJson({'appIcon': 'independence_day'});
      expect(c.appIcon, 'independence_day');
    });

    test('is null when the key is absent', () {
      final c = CommonUiConfig.fromJson({'IsUserUpdateProfile': true});
      expect(c.appIcon, isNull);
      // Existing behaviour must be unaffected.
      expect(c.isUserUpdateProfile, isTrue);
    });

    test('is null for blank values', () {
      expect(CommonUiConfig.fromJson({'AppIcon': '   '}).appIcon, isNull);
      expect(CommonUiConfig.fromJson({'AppIcon': ''}).appIcon, isNull);
    });

    test('does not throw when the backend sends a non-string', () {
      expect(CommonUiConfig.fromJson({'AppIcon': 42}).appIcon, isNull);
      expect(CommonUiConfig.fromJson({'AppIcon': true}).appIcon, isNull);
      expect(
        CommonUiConfig.fromJson({'AppIcon': {'nested': 1}}).appIcon,
        isNull,
      );
    });
  });

  group('UserAppConfiguration.fromJson', () {
    test('surfaces appIcon through the full nested payload', () {
      final config = UserAppConfiguration.fromJson({
        'CommonUiConfig': {
          'IsUserUpdateProfile': true,
          'AppIcon': 'independence_day',
        },
      });

      expect(config.commonUiConfig.appIcon, 'independence_day');
      expect(
        DynamicAppIconConfigMapper.resolve(config.commonUiConfig.appIcon),
        DynamicAppIcon.independenceDay,
      );
    });

    test('tolerates a payload with no CommonUiConfig at all', () {
      final config = UserAppConfiguration.fromJson(const {});
      expect(config.commonUiConfig.appIcon, isNull);
    });
  });
}
