import SwiftUI
import FirebaseAuth
import CoreLocation // ★追加

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userService: UserService
    
    // ★追加: 位置情報管理用（アプリ全体で保持する場合はここ、またはAppファイルで管理）
    @StateObject var locationManager = LocationManager()
    
    var body: some View {
        Group {
            if authService.userSession != nil {
                // ログイン済みの場合の判定
                if let user = userService.currentUserProfile, user.isAccountLocked {
                    // アカウントがロックされている場合は停止画面を表示
                    LockedAccountView()
                } else {
                    // 通常のメイン画面を表示
                    MainTabView()
                        .task {
                            if let uid = authService.userSession?.uid {
                                print("DEBUG: ContentViewでユーザー情報を取得開始")
                                try? await userService.fetchOrCreateUserProfile(uid: uid)
                                
                                // ★追加: 起動時に一度だけ位置情報を更新
                                if let location = locationManager.location {
                                    await userService.updateUserLocation(location: location)
                                }
                            }
                        }
                }
            } else {
                // 未ログイン -> ログイン画面を表示
                AuthenticationView()
            }
        }
    }
}

// タブバーの構成
struct MainTabView: View {
    var body: some View {
        TabView {
            DiscoveryView()
                .tabItem {
                    Label("探す", systemImage: "magnifyingglass")
                }
            
            MessageListView()
                .tabItem {
                    Label("メッセージ", systemImage: "bubble.left.and.bubble.right.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("マイページ", systemImage: "person.circle.fill")
                }
        }
        .accentColor(.brandPurple)
    }
}
