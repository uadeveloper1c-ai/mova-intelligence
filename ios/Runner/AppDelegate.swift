import Flutter
import UIKit
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

    private func clearApplicationBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()

            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            }
        }
    }

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        FirebaseApp.configure()

        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {

            let badgeChannel = FlutterMethodChannel(
                name: "mova_intelligence_app/badge",
                binaryMessenger: controller.binaryMessenger
            )

            badgeChannel.setMethodCallHandler { call, result in
                switch call.method {

                case "clearBadge":
                    self.clearApplicationBadge()
                    result(nil)

                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        clearApplicationBadge()
    }
}