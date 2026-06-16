import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final token = sl<AuthLocalStorage>().getAccessToken();
    final loggedIn = token != null && token.isNotEmpty;

    return MaterialApp(
      title: 'Commutr',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Manrope',
      ),
      home: loggedIn ? const Welcome() : const MobileNoVerification(),
    );
  }
}
