import 'package:flutter/material.dart';
import 'core/services/dynamic_app_icon/dynamic_app_icon.dart';
import 'core/services/dynamic_app_icon/dynamic_app_icon_service.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final s = DynamicAppIconService();
  debugPrint('IPADCHK supported: ${await s.isSupported()}');
  debugPrint('IPADCHK available: ${await s.getAvailableIcons()}');
  debugPrint('IPADCHK before: ${(await s.getCurrentIcon()).name}');
  final ok = await s.setIcon(DynamicAppIcon.independenceDay, deferUntilBackground: false);
  debugPrint('IPADCHK setIcon: $ok');
  debugPrint('IPADCHK after: ${(await s.getCurrentIcon()).name}');
  debugPrint('IPADCHK DONE');
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('ipad check')))));
}
