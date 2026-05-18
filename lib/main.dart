import 'package:commutr_main/app.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/ai_chatbot/chat_inapp.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(AuthLocalStorage.boxName);
  await Hive.openBox(kEtsChatHiveBoxName);
  setupDependencies();
  runApp(const CommutrApp());
}
