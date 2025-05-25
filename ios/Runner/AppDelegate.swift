import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging // <-- Import necesario para FCM

@main
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 1. Configura Firebase
        FirebaseApp.configure()
        
        // 2. Configura FCM (Notificaciones push)
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        
        // 3. Registra plugins de Flutter
        GeneratedPluginRegistrant.register(with: self)
        
        // 4. Solicita permiso para notificaciones (opcional)
        requestNotificationPermission(application)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Manejo del token APNs (requerido para FCM)
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
    
    // MARK: - Configuración de notificaciones en primer plano (iOS 10+)
    @available(iOS 10.0, *)
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Muestra notificaciones incluso cuando la app está en primer plano
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // MARK: - Método auxiliar para solicitar permisos
    private func requestNotificationPermission(_ application: UIApplication) {
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                }
            }
        } else {
            let settings = UIUserNotificationSettings(
                types: [.alert, .badge, .sound],
                categories: nil
            )
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
    }
}