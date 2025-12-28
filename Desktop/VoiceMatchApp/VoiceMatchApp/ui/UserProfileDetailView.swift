import SwiftUI
import UserNotifications

struct UserProfileDetailView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    let user: UserProfile
    let commonPoints: Int
    
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var isLiking = false
    @State private var showLikeSuccess = false
    @State private var showNotificationPrompt = false
    
    private var isAlreadyLiked: Bool {
        userService.currentUserProfile?.likedUserIDs.contains(user.uid) ?? false
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    selectionProfileSection
                    hashtagSection
                    voiceProfileSection
                    actionButtonsSection
                    reportBlockSection
                    Spacer(minLength: 50)
                }
                .padding(.top)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .alert("いいねを送りました！", isPresented: $showLikeSuccess) {
                Button("OK") {
                    checkNotificationStatus()
                }
            } message: {
                Text("相手もいいねを返してくれたらマッチ成立！\nマッチしたらメッセージ欄に表示されます。")
            }
            .alert("通知をオンにしますか？", isPresented: $showNotificationPrompt) {
                Button("オンにする") {
                    requestNotificationPermission()
                }
                Button("あとで", role: .cancel) {}
            } message: {
                Text("マッチやメッセージを見逃さないように、通知をオンにすることをおすすめします。")
            }
            .alert("ブロックしますか？", isPresented: $showBlockAlert) {
                Button("ブロック", role: .destructive) {
                    blockUser()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ブロックすると、このユーザーはあなたを見つけられなくなり、あなたもこのユーザーを見つけられなくなります。")
            }
            .sheet(isPresented: $showReportSheet) {
                ReportView(targetUserID: user.uid, targetUsername: user.username)
                    .environmentObject(userService)
            }
            .onDisappear {
                audioPlayer.stopPlayback()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            UserAvatarView(imageURL: user.iconImageURL, size: 120)
            
            Text(user.username)
                .font(.title)
                .fontWeight(.bold)
            
            if commonPoints > 0 {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text("\(commonPoints)個の共通点")
                        .font(.subheadline)
                        .foregroundColor(.brandPurple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandPurple.opacity(0.1))
                .cornerRadius(15)
            }
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    // MARK: - Selection Profile Section
    
    @ViewBuilder
    private var selectionProfileSection: some View {
        let publicItems = user.publicProfileItems
        if !publicItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("基本情報")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(ProfileConstants.selectionItems, id: \.key) { itemDef in
                    if let value = publicItems[itemDef.key] {
                        selectionItemRow(displayName: itemDef.displayName, value: value, key: itemDef.key)
                    }
                }
            }
            .padding(.vertical)
            .background(Color.white)
            .cornerRadius(15)
            .padding(.horizontal)
        }
    }
    
    private func selectionItemRow(displayName: String, value: String, key: String) -> some View {
        HStack {
            Text(displayName)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
            
            // 共通点マーク
            if let myValue = userService.currentUserProfile?.profileItems[key],
               myValue == value {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    // MARK: - Hashtag Section
    
    @ViewBuilder
    private var hashtagSection: some View {
        if !user.hashtags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("ハッシュタグ")
                    .font(.headline)
                    .padding(.horizontal)
                
                FlowLayout(spacing: 8) {
                    ForEach(user.hashtags, id: \.self) { tag in
                        hashtagChip(tag: tag)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(Color.white)
            .cornerRadius(15)
            .padding(.horizontal)
        }
    }
    
    private func hashtagChip(tag: String) -> some View {
        let isCommon = userService.currentUserProfile?.hashtags.contains(where: {
            $0.lowercased() == tag.lowercased()
        }) ?? false
        
        return HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
            
            if isCommon {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
        }
        .foregroundColor(isCommon ? .white : .brandPurple)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isCommon ? Color.brandPurple : Color.brandPurple.opacity(0.1))
        .cornerRadius(15)
    }
    
    // MARK: - Voice Profile Section
    
    private var voiceProfileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ボイス")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(VoiceProfileConstants.items) { item in
                if let voiceData = user.voiceProfiles[item.key] {
                    voiceRow(displayName: item.displayName, audioURL: voiceData.audioURL, duration: voiceData.duration)
                }
            }
        }
        .padding(.vertical)
        .background(Color.white)
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    private func voiceRow(displayName: String, audioURL: String, duration: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .fontWeight(.medium)
                Text(String(format: "%.1f秒", duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                togglePlayback(audioURL: audioURL)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isPlayingURL(audioURL) ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(isPlayingURL(audioURL) ? "停止" : "再生")
                        .font(.caption)
                }
                .foregroundColor(.brandPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.brandPurple.opacity(0.1))
                .cornerRadius(15)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private func isPlayingURL(_ url: String) -> Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == url
    }
    
    private func togglePlayback(audioURL: String) {
        if isPlayingURL(audioURL) {
            audioPlayer.stopPlayback()
        } else {
            if let url = URL(string: audioURL) {
                audioPlayer.startPlayback(url: url)
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // スキップ と いいね ボタン
            HStack(spacing: 40) {
                // スキップボタン
                Button(action: skipUser) {
                    VStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.gray)
                            )
                        Text("スキップ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // いいねボタン
                Button(action: sendLike) {
                    VStack {
                        Circle()
                            .fill(isAlreadyLiked ? Color.gray.opacity(0.1) : Color.pink.opacity(0.1))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Group {
                                    if isLiking {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(isAlreadyLiked ? .gray : .pink)
                                    }
                                }
                            )
                        Text(isAlreadyLiked ? "いいね済み" : "いいね")
                            .font(.caption)
                            .foregroundColor(isAlreadyLiked ? .gray : .pink)
                    }
                }
                .disabled(isAlreadyLiked || !userService.canSendLike() || isLiking)
            }
            
            // 残り回数表示
            if !isAlreadyLiked {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                        .font(.caption)
                    Text("残り \(userService.remainingLikes()) 回")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // いいね不可の場合のメッセージ
            if !isAlreadyLiked && !userService.canSendLike() {
                VStack(spacing: 4) {
                    Text("いいね上限に達しました")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("リセットまで: \(userService.formattedTimeUntilReset())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical)
        .background(Color.white)
        .cornerRadius(15)
        .padding(.horizontal)
    }
    
    // MARK: - Report & Block Section
    
    private var reportBlockSection: some View {
        HStack(spacing: 20) {
            Button(action: { showReportSheet = true }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("通報")
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            Button(action: { showBlockAlert = true }) {
                HStack {
                    Image(systemName: "hand.raised")
                    Text("ブロック")
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Actions
    
    private func skipUser() {
        Task {
            await userService.skipUser(targetUID: user.uid)
            dismiss()
        }
    }
    
    private func sendLike() {
        guard !isLiking else { return }
        isLiking = true
        
        Task {
            let success = await userService.sendLike(toUserID: user.uid)
            isLiking = false
            if success {
                showLikeSuccess = true
            }
        }
    }
    
    private func blockUser() {
        Task {
            await userService.blockUser(targetUID: user.uid)
            dismiss()
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    showNotificationPrompt = true
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - ReportView

struct ReportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var userService: UserService
    
    let targetUserID: String
    let targetUsername: String
    
    @State private var selectedReason = ""
    @State private var comment = ""
    @State private var isSubmitting = false
    
    let reasons = [
        "不適切なコンテンツ",
        "スパム・宣伝",
        "なりすまし",
        "嫌がらせ・いじめ",
        "不快な音声",
        "その他"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通報対象")) {
                    Text(targetUsername)
                        .fontWeight(.medium)
                }
                
                Section(header: Text("通報理由")) {
                    ForEach(reasons, id: \.self) { reason in
                        Button(action: {
                            selectedReason = reason
                        }) {
                            HStack {
                                Text(reason)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.brandPurple)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("詳細（任意）")) {
                    TextEditor(text: $comment)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("通報を送信")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(selectedReason.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        Task {
            await userService.reportUser(
                targetUID: targetUserID,
                reason: selectedReason,
                comment: comment,
                audioURL: nil
            )
            isSubmitting = false
            dismiss()
        }
    }
}

// FlowLayoutはFlowLayout.swiftで定義済み
