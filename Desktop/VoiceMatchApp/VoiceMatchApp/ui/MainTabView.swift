import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 探すタブ
            DiscoveryView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("探す")
                }
                .tag(0)
            
            // メッセージタブ
            MessageListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("メッセージ")
                }
                .tag(1)
            
            // プロフィールタブ
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("プロフィール")
                }
                .tag(2)
        }
        .tint(.brandPurple)
        .onAppear {
            loadUserData()
        }
    }
    
    private func loadUserData() {
        guard let user = authService.currentUser else { return }
        
        print("👤 ユーザーデータ読み込み: uid=\(user.uid)")
        
        Task {
            try? await userService.fetchOrCreateUserProfile(uid: user.uid)
            await userService.fetchUsersForDiscovery()
        }
    }
}
