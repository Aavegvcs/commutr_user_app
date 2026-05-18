import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/features/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/welcome/presentation/screen/welcome.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CommutrApp extends StatelessWidget {
  const CommutrApp({super.key});

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
