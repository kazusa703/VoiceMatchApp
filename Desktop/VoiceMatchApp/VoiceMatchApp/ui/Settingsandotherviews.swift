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
                }
                
                if let user = userService.currentUserProfile {
                    Section(header: Text("プッシュ通知設定")) {
                        Toggle("アプローチが届いた時", isOn: Binding(
                            get: { user.notificationSettings["approach"] ?? true },
                            set: { userService.updateNotificationSettings(key: "approach", isOn: $0) }
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
                        
                        Toggle(isOn: Binding(
                            get: { user.isLocationPublic },
                            set: { userService.updateLocationPublicStatus(isOn: $0) }
                        )) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse").foregroundColor(.brandPurple)
                                VStack(alignment: .leading) {
                                    Text("位置情報の公開")
                                    Text("Proユーザー同士でおおよその距離を表示します").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
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
                FeatureRow(icon: "infinity", text: "アプローチ送信し放題")
                FeatureRow(icon: "bolt.fill", text: "12時間の待機時間なし")
                FeatureRow(icon: "star.fill", text: "プロフィールの優先表示")
                FeatureRow(icon: "mic.fill", text: "高音質ボイスメッセージ")
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
                        UserAvatarView(imageURL: user.profileImageURL, size: 40)
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
                Text("複数のユーザーからの通報、または利用規約に違反する行為が確認されたため、このアカウントの使用を停止いたしました。")
                    .font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            
            VStack(spacing: 8) {
                Text("心当たりがない場合は").font(.caption).foregroundColor(.gray)
                Text("support@voicematch-app.com").font(.subheadline.bold()).foregroundColor(.brandPurple)
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
    
    @State private var selectedReason = "セクシャルハラスメント"
    @State private var comment = ""
    @State private var isSubmitting = false
    
    let reasons = ["セクシャルハラスメント", "嫌がらせ", "不快な音声", "スパム", "その他"]
    
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

// MARK: - UserProfileDetailView
struct UserProfileDetailView: View {
    let user: UserProfile
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                UserAvatarView(imageURL: user.profileImageURL, size: 150).padding(.top)
                Text(user.username).font(.title).fontWeight(.bold)
                
                if !user.bio.isEmpty {
                    Text(user.bio).multilineTextAlignment(.center).padding()
                }
                
                if let audioURL = user.bioAudioURL, let url = URL(string: audioURL) {
                    Button(action: {
                        if audioPlayer.isPlaying { audioPlayer.stopPlayback() }
                        else { audioPlayer.startPlayback(url: url) }
                    }) {
                        HStack {
                            Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            Text("自己紹介ボイスを再生")
                        }
                        .padding().background(Color.brandPurple.opacity(0.1)).cornerRadius(20)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("詳細データ").font(.headline)
                    ForEach(ProfileConstants.items, id: \.key) { item in
                        if user.privacySettings[item.key] ?? true,
                           let value = user.profileItems[item.key], !value.isEmpty {
                            HStack {
                                Text(item.displayName).foregroundColor(.secondary).frame(width: 100, alignment: .leading)
                                Text(value).fontWeight(.medium)
                            }
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.white).cornerRadius(10)
                .padding()
            }
        }
        .navigationTitle(user.username)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - VoiceBioRecordingView
struct VoiceBioRecordingView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var isUploading = false
    @State private var remainingTime: Double = 30.0
    @State private var timer: Timer?
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 30) {
            Text("自己紹介ボイス").font(.title2).fontWeight(.bold).padding(.top)
            
            Spacer()
            
            Text(String(format: "残り %.1f秒", remainingTime))
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(remainingTime < 5 ? .red : .primary)
            
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 4).frame(width: 180, height: 180)
                Circle().trim(from: 0.0, to: progress).stroke(Color.brandPurple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 180, height: 180).rotationEffect(.degrees(-90))
                
                Button(action: toggleRecording) {
                    Circle().fill(audioRecorder.isRecording ? Color.red : Color.brandPurple).frame(width: 90, height: 90)
                        .overlay(Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill").font(.system(size: 40)).foregroundColor(.white))
                }
            }
            
            if audioRecorder.recordingURL != nil && !audioRecorder.isRecording {
                HStack(spacing: 20) {
                    Button(action: resetRecording) {
                        VStack { Image(systemName: "arrow.counterclockwise"); Text("撮り直す").font(.caption) }.foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: previewAudio) {
                        VStack { Image(systemName: audioPlayer.isPlaying ? "stop.circle" : "play.circle"); Text(audioPlayer.isPlaying ? "停止" : "確認").font(.caption) }.foregroundColor(.brandPurple)
                    }
                    Spacer()
                    Button(action: saveVoice) {
                        if isUploading { ProgressView().frame(width: 100) }
                        else { Text("保存する").fontWeight(.bold).frame(width: 100) }
                    }
                    .padding(.vertical, 12).background(Color.brandPurple).foregroundColor(.white).cornerRadius(30).disabled(isUploading)
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
        }
        .padding()
        .onDisappear { timer?.invalidate(); audioPlayer.stopPlayback() }
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            timer?.invalidate()
        } else {
            audioPlayer.stopPlayback()
            remainingTime = 30.0; progress = 0.0
            audioRecorder.startRecording()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                remainingTime -= 0.1; progress += 0.1 / 30.0
                if remainingTime <= 0 { audioRecorder.stopRecording(); timer?.invalidate() }
            }
        }
    }
    
    private func resetRecording() {
        audioPlayer.stopPlayback()
        remainingTime = 30.0; progress = 0.0
    }
    
    private func previewAudio() {
        guard let url = audioRecorder.recordingURL else { return }
        if audioPlayer.isPlaying { audioPlayer.stopPlayback() }
        else { audioPlayer.startPlayback(url: url) }
    }
    
    private func saveVoice() {
        guard let url = audioRecorder.recordingURL else { return }
        isUploading = true
        Task {
            do {
                try await userService.uploadBioVoice(audioURL: url)
                await MainActor.run { dismiss() }
            } catch {
                print("エラー: \(error)")
                await MainActor.run { isUploading = false }
            }
        }
    }
}
