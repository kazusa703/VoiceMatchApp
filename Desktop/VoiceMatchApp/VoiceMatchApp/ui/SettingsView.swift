import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true
    
    @State private var isShowingLogoutAlert = false
    @State private var isShowingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("アカウント情報")) {
                    HStack {
                        Text("ログイン状態")
                        Spacer()
                        if let user = Auth.auth().currentUser {
                            Text(user.isAnonymous ? "ゲストユーザー" : (user.email ?? "ログイン中"))
                                .foregroundColor(user.isAnonymous ? .orange : .secondary)
                        }
                    }
                    
                    if let user = userService.currentUserProfile {
                        HStack {
                            Text("プラン")
                            Spacer()
                            Text(user.isProUser ? "Pro" : "無料")
                                .foregroundColor(user.isProUser ? .yellow : .secondary)
                        }
                    }
                }
                
                if let user = userService.currentUserProfile {
                    Section(header: Text("プッシュ通知設定")) {
                        Toggle("いいねが届いた時", isOn: Binding(
                            get: { user.notificationSettings["like"] ?? true },
                            set: { userService.updateNotificationSettings(key: "like", isOn: $0) }
                        ))
                        Toggle("マッチングした時", isOn: Binding(
                            get: { user.notificationSettings["match"] ?? true },
                            set: { userService.updateNotificationSettings(key: "match", isOn: $0) }
                        ))
                        Toggle("メッセージが届いた時", isOn: Binding(
                            get: { user.notificationSettings["message"] ?? true },
                            set: { userService.updateNotificationSettings(key: "message", isOn: $0) }
                        ))
                    }
                    
                    Section(header: Text("アプリ設定")) {
                        Toggle("バイブレーション", isOn: $isHapticsEnabled)
                    }
                    
                    Section(header: Text("コミュニティ管理")) {
                        NavigationLink(destination: SkippedUsersListView()) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward.circle")
                                Text("スキップしたユーザー")
                            }
                        }
                    }
                    
                    if user.isAdmin {
                        Section(header: Text("管理者設定")) {
                            NavigationLink(destination: AdminReportListView()) {
                                Label("通報管理画面へ", systemImage: "shield.checkerboard").foregroundColor(.red)
                            }
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
                    Task {
                        if let uid = userService.currentUserProfile?.uid {
                            try? await userService.deleteUserAccount(uid: uid)
                            try? await authService.deleteAccount()
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("アカウントと全てのデータが完全に削除されます。")
            }
        }
    }
}

// MARK: - SkippedUsersListView
struct SkippedUsersListView: View {
    @EnvironmentObject var userService: UserService
    @State private var skippedUsers: [UserProfile] = []
    
    var body: some View {
        List {
            if skippedUsers.isEmpty {
                Text("スキップしたユーザーはいません").foregroundColor(.secondary)
            } else {
                ForEach(skippedUsers) { user in
                    HStack {
                        UserAvatarView(imageURL: user.iconImageURL, size: 40)
                        Text(user.username)
                        Spacer()
                        Button("戻す") {
                            Task {
                                await userService.unskipUser(targetUID: user.uid)
                                skippedUsers.removeAll { $0.uid == user.uid }
                            }
                        }
                        .foregroundColor(.blue).buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("スキップしたユーザー")
        .task {
            if let ids = userService.currentUserProfile?.skippedUserIDs, !ids.isEmpty {
                skippedUsers = await userService.fetchUsersByIDs(uids: ids)
            }
        }
    }
}

// MARK: - LockedAccountView
struct LockedAccountView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Image(systemName: "exclamationmark.shield.fill").font(.system(size: 80)).foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("アカウントが停止されました").font(.title2.bold())
                Text("利用規約に違反する行為が確認されたため、このアカウントの使用を停止いたしました。")
                    .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: { authService.signOut() }) {
                Text("ログアウトして戻る").fontWeight(.bold).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding().background(Color.gray).cornerRadius(30)
            }
            .padding(.horizontal, 40).padding(.bottom, 50)
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
    }
}

// MARK: - ReportSheetView
struct ReportSheetView: View {
    let targetUID: String
    let audioURL: String?
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedReason = "不快なコンテンツ"
    @State private var comment = ""
    @State private var isSubmitting = false
    
    let reasons = ["不快なコンテンツ", "嫌がらせ", "スパム", "その他"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通報の理由")) {
                    Picker("理由を選択", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                }
                Section(header: Text("詳細 (任意)")) {
                    TextEditor(text: $comment).frame(height: 100)
                }
            }
            .navigationTitle("通報")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("送信") {
                        isSubmitting = true
                        Task {
                            await userService.reportUser(targetUID: targetUID, reason: selectedReason, comment: comment, audioURL: audioURL)
                            dismiss()
                        }
                    }.disabled(isSubmitting)
                }
            }
        }
    }
}

// MARK: - AdminReportListView
struct AdminReportListView: View {
    @EnvironmentObject var userService: UserService
    @State private var reports: [Report] = []
    
    private let db = Firestore.firestore()
    
    var body: some View {
        List {
            if reports.isEmpty {
                Text("通報はありません").foregroundColor(.secondary)
            }
            ForEach(reports) { report in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(report.reason).font(.headline).foregroundColor(.red)
                        Spacer()
                        Text(report.timestamp, style: .date).font(.caption).foregroundColor(.secondary)
                    }
                    if !report.comment.isEmpty {
                        Text(report.comment).font(.caption).padding(8).background(Color.gray.opacity(0.1)).cornerRadius(5)
                    }
                    HStack {
                        Button("停止") {
                            Task { await userService.updateAccountLockStatus(targetUID: report.targetID, isLocked: true) }
                        }.buttonStyle(.bordered).foregroundColor(.red)
                        Button("解除") {
                            Task { await userService.updateAccountLockStatus(targetUID: report.targetID, isLocked: false) }
                        }.buttonStyle(.bordered).foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("通報一覧")
        .onAppear { fetchReports() }
    }
    
    private func fetchReports() {
        db.collection("reports").order(by: "timestamp", descending: true).addSnapshotListener { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            self.reports = docs.compactMap { try? $0.data(as: Report.self) }
        }
    }
}

// MARK: - PaywallView
struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").foregroundColor(.primary).padding()
                }
            }
            
            Spacer()
            
            Image(systemName: "crown.fill").font(.system(size: 80)).foregroundColor(.yellow)
            
            Text("Proプランにアップグレード").font(.title).fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "heart.fill", text: "いいね100回/日（通常10回）")
                FeatureRow(icon: "waveform", text: "10種類のボイスエフェクト")
                FeatureRow(icon: "slider.horizontal.3", text: "エフェクトの細かい調整")
                FeatureRow(icon: "eye.slash", text: "広告非表示")
                FeatureRow(icon: "line.3.horizontal.decrease.circle", text: "必須条件フィルター無制限")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                purchaseManager.purchasePro()
                dismiss()
            }) {
                VStack(spacing: 4) {
                    Text("Proプランに登録").fontWeight(.bold)
                    Text("$9.99 / 月").font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient.instaGradient)
                .cornerRadius(30)
            }
            .padding(.horizontal)
            
            Button("購入を復元する") { purchaseManager.restorePurchases() }
                .font(.caption).foregroundColor(.gray)
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.brandPurple).frame(width: 24)
            Text(text)
        }
    }
}
