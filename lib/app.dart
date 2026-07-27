import 'dart:async';

import 'package:commutr_main/commutr_ltr/commutr_ltr_home/commutr_ltr_home.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_login/ltr_session_storage.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/features/shorebird_update/shorebird_update.dart';
import 'package:commutr_main/features/version_check/version_check_service.dart';
import 'package:commutr_main/welcome/presentation/screen/welcome.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CommutrApp extends StatefulWidget {
  const CommutrApp({super.key});

  @override
  State<CommutrApp> createState() => _CommutrAppState();
}

class _CommutrAppState extends State<CommutrApp> {
  final ShorebirdUpdateManager _shorebirdUpdateManager =
      ShorebirdUpdateManager();

  @override
  void initState() {
    super.initState();
    // Run the app version check once the first frame is rendered so a
    // force-update dialog has a navigator/overlay to attach to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        VersionCheckService.checkOnAppOpen(context);
      }
    });

    // When a Shorebird OTA patch finishes downloading, prompt the user to
    // restart so it can be applied. Non-blocking; the patch also applies
    // automatically on the next natural restart.
    _shorebirdUpdateManager.restartRequired.addListener(_onRestartRequired);

    // Check for and download an OTA patch off the startup critical path.
    // Fire-and-forget: never awaited, never throws.
    unawaited(_shorebirdUpdateManager.checkAndDownload());
  }

  void _onRestartRequired() {
    if (!_shorebirdUpdateManager.restartRequired.value) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Update ready. Restart the app to apply.'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  void dispose() {
    _shorebirdUpdateManager.restartRequired.removeListener(_onRestartRequired);
    _shorebirdUpdateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A valid, unexpired LTR session takes priority: send the user straight to
    // the LTR home so they don't have to re-enter the flow on every app open.
    final hasValidLtrSession = LtrSessionStorage().hasValidSession;

    final token = sl<AuthLocalStorage>().getAccessToken();
    final loggedIn = token != null && token.isNotEmpty;

    final Widget home;
    if (hasValidLtrSession) {
      home = const CommutrLtrHome();
    } else if (loggedIn) {
      home = const Welcome();
    } else {
      home = const MobileNoVerification();
    }

    return MaterialApp(
      title: 'Commutr',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Manrope',
      ),
      home: home,
    );
  }
}
