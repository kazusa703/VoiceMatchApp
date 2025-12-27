import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications
import FirebaseFirestore
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    // 通知タップ時にタブを切り替えるため、MessageServiceを保持
    var messageService: MessageService?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        return true
    }
    
    // トークンが発行・更新された時にFirestoreへ保存
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken, let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users").document(uid).updateData(["fcmToken": token])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // 通知をタップした際、アプリ内のセクションを自動で切り替え
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String {
            DispatchQueue.main.async {
                switch type {
                case "chat", "match":
                    self.messageService?.selectedSection = .matches
                case "approach":
                    self.messageService?.selectedSection = .received
                default:
                    break
                }
            }
        }
        completionHandler()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

@main
struct VoiceMatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject var authService = AuthService()
    @StateObject var userService = UserService()
    @StateObject var messageService = MessageService()
    @StateObject var purchaseManager = PurchaseManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(userService)
                .environmentObject(messageService)
                .environmentObject(purchaseManager)
                .onAppear {
                    // AppDelegateと連携
                    delegate.messageService = messageService
                    // RevenueCat API Key（本番環境では環境変数等で管理推奨）
                    purchaseManager.configure(apiKey: "test_BeUPQCjIdabnSbhkFxfsZnCrvAC")
                }
        }
    }
}
