import SwiftUI
import FirebaseCore
import FirebaseAuth
import RevenueCat // ★必要

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct VoiceMatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 各サービスをここで初期化
    @StateObject var authService = AuthService()
    @StateObject var userService = UserService()
    @StateObject var messageService = MessageService()
    @StateObject var purchaseManager = PurchaseManager.shared // ★修正: sharedを使う
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(userService)
                .environmentObject(messageService)
                .environmentObject(purchaseManager)
                .onAppear {
                    // ★重要: ここに RevenueCat の APIキーを入れてください
                    // "appl_" で始まるキーが RevenueCat のダッシュボードにあります
                    purchaseManager.configure(apiKey: "test_BeUPQCjIdabnSbhkFxfsZnCrvAC")
                }
        }
    }
}
