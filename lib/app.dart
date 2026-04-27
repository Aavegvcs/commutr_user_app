import 'package:commutr_main/auth/presentation/screens/mobile_no_verification.dart';
import 'package:commutr_main/auth/presentation/screens/signup.dart';
import 'package:flutter/material.dart';

class CommutrApp extends StatelessWidget {
  const CommutrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commutr',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Manrope',
      ),
      home: const MobileNoVerification(),
    );
  }
}
