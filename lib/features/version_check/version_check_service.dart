import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/injection.dart';
import 'data/repository/version_check_repository.dart';

/// Play Store listing for the Commutr user app.
const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.user.asnd.commutr&pcampaignid=web_share';

/// App Store listing for the Commutr user app.
const String _appStoreUrl =
    'https://apps.apple.com/in/app/commutr-asnd/id6779981087';

/// `appType` for the Commutr user app.
const int _appType = 2;

/// `platform` values expected by the API (1 = iOS, 2 = Android).
const int _platformIos = 2;
const int _platformAndroid = 1;

/// Runs the version check on app open and, when a force update is required,
/// shows a blocking dialog that sends the user to the store.
abstract final class VersionCheckService {
  VersionCheckService._();

  static Future<void> checkOnAppOpen(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? _platformIos : _platformAndroid;

      final response = await sl<VersionCheckRepository>().checkVersion(
        appType: _appType,
        platform: platform,
        currentVersion: info.version,
      );

      final data = response.data;
      if (data == null || !data.isForceUpdate) return;
      if (!context.mounted) return;

      await _showForceUpdateDialog(context);
    } catch (e) {
      // Never block app open if the version check fails (network/parse error).
      debugPrint('[VERSION_CHECK] failed: $e');
    }
  }

  static Future<void> _showForceUpdateDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
            'A new version of Commutr is available. Please update to continue '
            'using the app.',
          ),
          actions: [
            TextButton(
              onPressed: _openStore,
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openStore() async {
    final uri = Uri.parse(Platform.isIOS ? _appStoreUrl : _playStoreUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
