import 'package:commutr_main/app.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  runApp(const CommutrApp());
}
