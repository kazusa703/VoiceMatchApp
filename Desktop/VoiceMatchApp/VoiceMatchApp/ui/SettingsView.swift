import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true
    
    @State private var isShowingLogoutAlert = false
    @State private var isShowingDeleteAlert = false
    @State private var isDeleting = false
    @State private var showResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("アカウント情報")) {
                    HStack {
                        Text("ログイン状態")
                        Spacer()
                        if let user = Auth.auth().currentUser {
                            if user.isAnonymous {
                                Text("ゲストユーザー").foregroundColor(.orange)
                            } else {
                                Text(user.email ?? "ログイン中").foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let user = userService.currentUserProfile {
                    Section(header: Text("プッシュ通知設定")) {
                        Toggle("アプローチが届いた時", isOn: Binding(
                            get: { user.notificationSettings["approach"] ?? true },
                            set: { userService.updateNotificationSettings(key: "approach", isOn: $0) }
                        ))
                        
                        Toggle("メッセージが届いた時", isOn: Binding(
                            get: { user.notificationSettings["message"] ?? true },
                            set: { userService.updateNotificationSettings(key: "message", isOn: $0) }
                        ))
                    }
                }
                
                Section(header: Text("アプリ設定")) {
                    Toggle("バイブレーション", isOn: $isHapticsEnabled)
                    
                    if let user = userService.currentUserProfile {
                        Toggle(isOn: Binding(
                            get: { user.isLocationPublic ?? false },
                            set: { userService.updateLocationPublicStatus(isOn: $0) }
                        )) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.brandPurple)
                                VStack(alignment: .leading) {
                                    Text("位置情報の公開")
                                    Text("Proユーザー同士でおおよその距離を表示します").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // ★追加: コミュニティ管理セクション
                Section(header: Text("コミュニティ管理")) {
                    NavigationLink(destination: SkippedUsersListView()) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .foregroundColor(.blue)
                            Text("スキップしたユーザー")
                        }
                    }
                }

                if let user = userService.currentUserProfile, user.isAdmin {
                    Section(header: Text("管理者設定")) {
                        NavigationLink(destination: AdminReportListView()) {
                            Label("通報管理画面へ", systemImage: "shield.checkerboard")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button("ログアウト", role: .destructive) { isShowingLogoutAlert = true }
                    Button("アカウント削除", role: .destructive) { isShowingDeleteAlert = true }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("ログアウト", isPresented: $isShowingLogoutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    authService.signOut()
                    dismiss()
                }
            }
            .alert("アカウント削除", isPresented: $isShowingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除する", role: .destructive) {
                    performDeleteAccount()
                }
            }
        }
    }
    
    private func performDeleteAccount() {
        guard let uid = userService.currentUserProfile?.uid else { return }
        isDeleting = true
        Task {
            do {
                try await userService.deleteUserAccount(uid: uid)
                try await authService.deleteAccount()
                isDeleting = false
                await MainActor.run { dismiss() }
            } catch {
                print("削除エラー: \(error)")
                isDeleting = false
            }
        }
    }
}
