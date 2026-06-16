import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase natively before any plugin touches it, so native code
    // (e.g. firebase_messaging during registration) no longer logs
    // "No app has been configured yet". The Dart-side Firebase.initializeApp in
    // main.dart safely reuses this already-configured default app.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Initialize the Google Maps SDK before any GMSMapView is created.
    // google_maps_flutter on iOS requires GMSServices.provideAPIKey to be
    // called up front, otherwise the SDK throws:
    // "Google Maps SDK for iOS must be initialized via [GMSServices provideAPIKey:...]".
    GMSServices.provideAPIKey("AIzaSyCWbmCiquOta1iF6um7_5_NFh6YM5wPL30")

    // Allow flutter_local_notifications to display alerts when the app is
    // in the foreground (iOS 10+).
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    // This app uses the UIScene lifecycle (FlutterSceneDelegate), so the
    // window/rootViewController do NOT exist yet here — they are created later
    // when the scene connects. flutter_contacts force-unwraps
    // `UIApplication.shared.delegate!.window!!.rootViewController!` at plugin
    // registration time and crashes if that window is nil. So we (1) make sure
    // the AppDelegate has a window reference, and (2) defer registration until a
    // key window with a rootViewController actually exists.
    registerPluginsWhenWindowIsReady()

    return result
  }

  private func registerPluginsWhenWindowIsReady() {
    // Mirror the active scene's window onto the AppDelegate so the
    // `delegate.window` force-unwrap in flutter_contacts succeeds.
    if self.window == nil {
      self.window = activeKeyWindow()
    }

    guard self.window?.rootViewController != nil else {
      // Window/rootViewController not attached yet; try again on the next
      // run-loop tick once the scene has connected.
      DispatchQueue.main.async { [weak self] in
        self?.registerPluginsWhenWindowIsReady()
      }
      return
    }

    GeneratedPluginRegistrant.register(with: self)
  }

  private func activeKeyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow } ??
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first
  }
}
