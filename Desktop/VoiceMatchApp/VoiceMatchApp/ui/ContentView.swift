import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService()
    @StateObject private var userService = UserService()
    @StateObject private var purchaseManager = PurchaseManager()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(userService)
                    .environmentObject(purchaseManager)
            } else {
                AuthView()
                    .environmentObject(authService)
            }
        }
    }
}

#Preview {
    ContentView()
}
