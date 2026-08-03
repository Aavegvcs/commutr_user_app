import 'dart:io';

import 'package:commutr_main/app.dart';
import 'package:commutr_main/core/di/injection.dart';
import 'package:commutr_main/commutr_ltr/commutr_ltr_login/ltr_session_storage.dart';
import 'package:commutr_main/core/storage/auth_local_storage.dart';
import 'package:commutr_main/ride_tracking/service/live_trip_fcm_handler.dart';
import 'package:commutr_main/ride_tracking/service/live_trip_notification_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'features/ai_chatbot/chat_inapp.dart';
import 'firebase_options.dart';

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'commutr_high_importance_channel',
  'Commutr Notifications',
  description: 'Trip and ride notifications from Commutr.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Handles FCM messages when the app is terminated or in the background.
///
/// Runs in a SEPARATE isolate where `main()` never executed — no DI, no widget
/// tree, and plugins must be initialised locally.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Live-trip updates must still render when the app is killed — this is the
  // only path that can reach the device once the SignalR socket is gone.
  if (LiveTripFcmHandler.handles(message)) {
    // The plugin is uninitialised in this isolate; without this the show() call
    // silently no-ops.
    await initLocalNotificationsForBackgroundIsolate();
    await LiveTripFcmHandler.handle(message);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background message handler must be registered before any other Firebase
  // Messaging calls.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initLocalNotifications();
  await _requestNotificationPermission();

  FirebaseMessaging.instance.onTokenRefresh.listen(
    (token) {
      debugPrint('[FCM] Token refreshed: $token');

      // The token can rotate at any time (app data cleared, reinstall, FCM
      // server rotation). If the user is already logged in, push the new token
      // to the backend so notifications keep arriving. When not logged in the
      // next verifyOtp() will send the current token anyway.
      // TODO: if a session exists, call your "update device token" endpoint
      // here via the DI'd ApiClient, e.g.
      //   if (authLocalStorage.isLoggedIn) deviceRepository.updateFcmToken(token);
    },
    onError: (error) {
      debugPrint('[FCM] Token refresh error: $error');
    },
  );

  // Handle FCM messages received while the app is in the foreground.
  //
  // Android: the OS does NOT show a banner for data/notification messages while
  // the app is foregrounded, so we render one ourselves via local
  // notifications.
  // iOS: setForegroundNotificationPresentationOptions (below) tells the system
  // to present the banner itself, so we must NOT also show a local
  // notification here or it would appear twice.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Live-trip updates are DATA-ONLY (no `notification` block), so they must be
    // intercepted before the null-notification early-return below — otherwise
    // they'd be dropped silently while the app is foregrounded.
    if (LiveTripFcmHandler.handles(message)) {
      LiveTripFcmHandler.handle(message);
      return;
    }

    final notification = message.notification;
    if (notification == null) return;

    if (Platform.isAndroid) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  await Hive.initFlutter();
  await Hive.openBox(AuthLocalStorage.boxName);
  await Hive.openBox(kEtsChatHiveBoxName);
  await Hive.openBox(LtrSessionStorage.boxName);
  setupDependencies();
  runApp(const CommutrApp());
}

Future<void> _initLocalNotifications() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  const initSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const initSettings = InitializationSettings(
    android: initSettingsAndroid,
    iOS: initSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
  );

  // The app may have been launched *by* tapping the ongoing trip notification
  // while it was terminated. In that case the callback above never fires, so the
  // launch details have to be read explicitly and routed after the first frame
  // (the navigator doesn't exist yet at this point).
  final launchDetails = await flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true) {
    final payload = launchDetails!.notificationResponse?.payload;
    if (payload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openTrackingFromNotificationPayload(payload);
      });
    }
  }
}

/// Routes a notification tap. Only handles the ongoing live-trip notification;
/// any other payload is ignored so FCM behaviour is unchanged.
void _onNotificationTapped(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null) return;
  openTrackingFromNotificationPayload(payload);
}

Future<void> _requestNotificationPermission() async {
  if (Platform.isIOS) {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } else {
    // Android 13+ requires POST_NOTIFICATIONS; flutter_local_notifications
    // handles the runtime prompt automatically on Android.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Keep FCM token in foreground delivery mode so the system doesn't suppress
  // heads-up banners when the app is open.
  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}
