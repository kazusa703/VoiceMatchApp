import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true
    @AppStorage("hasAgreedToTerms") private var hasAgreedToTerms = false
    @AppStorage("agreedUserID") private var agreedUserID = ""
    
    @State private var isShowingLogoutAlert = false
    @State private var isShowingDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationView {
            List {
                // アカウント情報
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
                
                // プッシュ通知設定
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
                    
                    // アプリ設定
                    Section(header: Text("アプリ設定")) {
                        Toggle("バイブレーション", isOn: $isHapticsEnabled)
                    }
                    
                    // コミュニティ管理
                    Section(header: Text("コミュニティ管理")) {
                        NavigationLink(destination: SkippedUsersListView()) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .foregroundColor(.blue)
                                Text("スキップしたユーザー")
                            }
                        }
                        
                        NavigationLink(destination: BlockedUsersListView()) {
                            HStack {
                                Image(systemName: "nosign")
                                    .foregroundColor(.red)
                                Text("ブロックしたユーザー")
                            }
                        }
                    }
                    
                    // 管理者設定
                    if user.isAdmin {
                        Section(header: Text("管理者設定")) {
                            NavigationLink(destination: AdminReportListView()) {
                                Label("通報管理画面へ", systemImage: "shield.checkerboard")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // 規約・ポリシー
                Section(header: Text("規約・ポリシー")) {
                    NavigationLink(destination: TermsOfServiceView()) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.gray)
                            Text("利用規約")
                        }
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.gray)
                            Text("プライバシーポリシー")
                        }
                    }
                }
                
                // アカウント操作
                Section {
                    Button(action: { isShowingLogoutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("ログアウト")
                        }
                        .foregroundColor(.orange)
                    }
                    
                    Button(action: { isShowingDeleteAlert = true }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("アカウントを削除")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isDeleting)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            // ログアウト確認
            .alert("ログアウト", isPresented: $isShowingLogoutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    authService.signOut()
                    dismiss()
                }
            } message: {
                Text("ログアウトしてもよろしいですか？")
            }
            // アカウント削除確認
            .alert("アカウントを削除", isPresented: $isShowingDeleteAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("削除する", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("アカウントを削除すると、以下のデータがすべて完全に削除されます。この操作は取り消せません。\n\n• プロフィール情報\n• 音声データ\n• マッチ履歴\n• メッセージ履歴")
            }
        }
    }
    
    private func deleteAccount() {
        guard let uid = userService.currentUserProfile?.uid else { return }
        
        isDeleting = true
        
        Task {
            do {
                // UserServiceでFirestore/Storageのデータを削除
                try await userService.deleteUserAccount(uid: uid)
                
                // 利用規約同意状態をリセット
                hasAgreedToTerms = false
                agreedUserID = ""
                
                // Firebase Authのアカウントを削除
                try await authService.deleteAccount()
                
                dismiss()
            } catch {
                print("アカウント削除エラー: \(error)")
                isDeleting = false
            }
        }
    }
}

// MARK: - SkippedUsersListView
struct SkippedUsersListView: View {
    @EnvironmentObject var userService: UserService
    @State private var skippedUsers: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if skippedUsers.isEmpty {
                Text("スキップしたユーザーはいません")
                    .foregroundColor(.secondary)
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
                        .foregroundColor(.blue)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("スキップしたユーザー")
        .task {
            if let ids = userService.currentUserProfile?.skippedUserIDs, !ids.isEmpty {
                skippedUsers = await userService.fetchUsersByIDs(uids: ids)
            }
            isLoading = false
        }
    }
}

// MARK: - BlockedUsersListView（新規追加）
struct BlockedUsersListView: View {
    @EnvironmentObject var userService: UserService
    @State private var blockedUsers: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if blockedUsers.isEmpty {
                Text("ブロックしたユーザーはいません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(blockedUsers) { user in
                    HStack {
                        UserAvatarView(imageURL: user.iconImageURL, size: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.username)
                            Text("ブロック中")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        Button("解除") {
                            Task {
                                await unblockUser(targetUID: user.uid)
                                blockedUsers.removeAll { $0.uid == user.uid }
                            }
                        }
                        .foregroundColor(.red)
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("ブロックしたユーザー")
        .task {
            if let ids = userService.currentUserProfile?.blockedUserIDs, !ids.isEmpty {
                blockedUsers = await userService.fetchUsersByIDs(uids: ids)
            }
            isLoading = false
        }
    }
    
    private func unblockUser(targetUID: String) async {
        guard let uid = userService.currentUserProfile?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            try await db.collection("users").document(uid).updateData([
                "blockedUserIDs": FieldValue.arrayRemove([targetUID])
            ])
            userService.currentUserProfile?.blockedUserIDs.removeAll { $0 == targetUID }
        } catch {
            print("ブロック解除エラー: \(error)")
        }
    }
}

// MARK: - LockedAccountView
struct LockedAccountView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 16) {
                Text("アカウントが停止されました")
                    .font(.title2.bold())
                
                Text("利用規約に違反する行為が確認されたため、このアカウントの使用を停止いたしました。")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: { authService.signOut() }) {
                Text("ログアウトして戻る")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .cornerRadius(30)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
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
    @State private var showSuccessAlert = false
    
    let reasons = ["不快なコンテンツ", "嫌がらせ・誹謗中傷", "スパム・迷惑行為", "なりすまし", "その他"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通報の理由")) {
                    Picker("理由を選択", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.inline)
                }
                
                Section(header: Text("詳細（任意）")) {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                    
                    Text("具体的な状況を記載いただくと、より適切な対応が可能になります")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Text("通報内容は運営チームが確認し、利用規約に基づいて対応いたします。虚偽の通報は禁止されています。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("通報")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("送信") {
                        submitReport()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("通報を送信しました", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("ご報告ありがとうございます。内容を確認の上、適切に対応いたします。")
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        Task {
            await userService.reportUser(
                targetUID: targetUID,
                reason: selectedReason,
                comment: comment,
                audioURL: audioURL
            )
            showSuccessAlert = true
            isSubmitting = false
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
                Text("通報はありません")
                    .foregroundColor(.secondary)
            }
            ForEach(reports) { report in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(report.reason)
                            .font(.headline)
                            .foregroundColor(.red)
                        Spacer()
                        Text(report.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !report.comment.isEmpty {
                        Text(report.comment)
                            .font(.caption)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                    
                    HStack {
                        Button("停止") {
                            Task {
                                await userService.updateAccountLockStatus(targetUID: report.targetID, isLocked: true)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Button("解除") {
                            Task {
                                await userService.updateAccountLockStatus(targetUID: report.targetID, isLocked: false)
                            }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("通報一覧")
        .onAppear { fetchReports() }
    }
    
    private func fetchReports() {
        db.collection("reports")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, _ in
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
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                        .padding()
                }
            }
            
            Spacer()
            
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("Proプランにアップグレード")
                .font(.title)
                .fontWeight(.bold)
            
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
                    Text("Proプランに登録")
                        .fontWeight(.bold)
                    Text("$9.99 / 月")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient.instaGradient)
                .cornerRadius(30)
            }
            .padding(.horizontal)
            
            Button("購入を復元する") {
                purchaseManager.restorePurchases()
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brandPurple)
                .frame(width: 24)
            Text(text)
        }
    }
}
