import SwiftUI
import UserNotifications

struct DiscoveryView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var authService: AuthService
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var isLoading = true
    @State private var currentIndex = 0
    @State private var showUserDetail = false
    @State private var selectedUser: UserProfile?
    @State private var showLikedUsers = false
    @State private var showFilter = false
    
    // 絞り込み条件
    @State private var filterConditions: [String: String] = [:]
    @State private var minCommonPoints: Int = 0
    @State private var commonPointsMode: String = "none"
    @State private var maxDistance: Double = 100
    
    // 戻る機能用
    @State private var previousUser: UserProfile?
    @State private var canGoBack = false
    
    // いいね送信後のアラート
    @State private var showLikeAlert = false
    @State private var showNotificationPrompt = false
    
    // フィルタリングされたユーザーリスト
    private var filteredUsers: [UserProfile] {
        var users = userService.discoveryUsers
        
        // いいね済みフィルター
        if !showLikedUsers {
            users = users.filter { user in
                !(userService.currentUserProfile?.likedUserIDs.contains(user.uid) ?? false)
            }
        }
        
        // 選択式絞り込み条件を適用（AND検索）
        for (key, value) in filterConditions {
            if !value.isEmpty && value != "指定なし" {
                users = users.filter { user in
                    user.profileItems[key] == value
                }
            }
        }
        
        // 共通点フィルター
        if commonPointsMode != "none" && minCommonPoints > 0 {
            users = users.filter { user in
                userService.calculateCommonPoints(with: user) >= minCommonPoints
            }
        }
        
        return users
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("ユーザーを探しています...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if filteredUsers.isEmpty {
                    emptyStateView
                } else {
                    userCardView
                }
            }
            .navigationTitle("探す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        // いいね済み表示トグル
                        Button(action: {
                            showLikedUsers.toggle()
                            currentIndex = 0
                        }) {
                            Image(systemName: showLikedUsers ? "heart.fill" : "heart.slash")
                                .foregroundColor(showLikedUsers ? .pink : .gray)
                        }
                        
                        // 絞り込みボタン
                        Button(action: {
                            showFilter = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.brandPurple)
                        }
                        
                        // 戻るボタン
                        Button(action: goBackToPreviousUser) {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(canGoBack ? .brandPurple : .gray.opacity(0.3))
                        }
                        .disabled(!canGoBack)
                    }
                }
            }
            .sheet(isPresented: $showUserDetail) {
                if let user = selectedUser {
                    UserProfileDetailView(user: user, commonPoints: userService.calculateCommonPoints(with: user))
                        .environmentObject(userService)
                        .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showFilter) {
                FilterView(
                    filterConditions: $filterConditions,
                    minCommonPoints: $minCommonPoints,
                    commonPointsMode: $commonPointsMode,
                    maxDistance: $maxDistance
                )
                .environmentObject(userService)
            }
            .alert("いいねを送りました！", isPresented: $showLikeAlert) {
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
            .refreshable {
                await refreshUsersAsync()
            }
            .onAppear {
                loadUsers()
            }
            .onDisappear {
                audioPlayer.stopPlayback()
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("表示できるユーザーがいません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("条件を変更するか、時間をおいてお試しください")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !showLikedUsers {
                Button(action: {
                    showLikedUsers = true
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("いいね済みを表示")
                    }
                    .font(.caption)
                    .foregroundColor(.pink)
                }
                .padding(.top, 5)
            }
        }
        .padding()
    }
    
    // MARK: - User Card View
    
    private var userCardView: some View {
        VStack(spacing: 16) {
            // ステータスバー
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.pink)
                    Text("残り \(userService.remainingLikes()) 回")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if showLikedUsers {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("済みも表示中")
                            .font(.caption2)
                    }
                    .foregroundColor(.pink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Spacer()
                
                Text("\(currentIndex + 1) / \(filteredUsers.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // ユーザーカード
            if currentIndex < filteredUsers.count {
                let user = filteredUsers[currentIndex]
                let isAlreadyLiked = userService.currentUserProfile?.likedUserIDs.contains(user.uid) ?? false
                
                VStack(spacing: 0) {
                    Button(action: {
                        selectedUser = user
                        showUserDetail = true
                    }) {
                        VStack(spacing: 16) {
                            if isAlreadyLiked {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text("いいね済み")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.pink)
                                .cornerRadius(15)
                            }
                            
                            UserAvatarView(imageURL: user.iconImageURL, size: 120)
                            
                            Text(user.username)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            CommonPointsBadge(count: userService.calculateCommonPoints(with: user))
                            
                            if let introVoice = user.voiceProfiles["introduction"] ?? user.voiceProfiles["naturalVoice"] {
                                VoicePlayButton(
                                    audioURL: introVoice.audioURL,
                                    duration: introVoice.duration,
                                    audioPlayer: audioPlayer
                                )
                            }
                            
                            Text("タップして詳細を見る")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(30)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                Spacer()
                
                // アクションボタン（スキップ と いいね）
                HStack(spacing: 60) {
                    // スキップボタン
                    Button(action: {
                        skipCurrentUser()
                    }) {
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
                    Button(action: {
                        sendLikeToCurrentUser()
                    }) {
                        VStack {
                            Circle()
                                .fill(isAlreadyLiked ? Color.gray.opacity(0.1) : Color.pink.opacity(0.1))
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(isAlreadyLiked ? .gray : .pink)
                                )
                            Text(isAlreadyLiked ? "いいね済み" : "いいね")
                                .font(.caption)
                                .foregroundColor(isAlreadyLiked ? .gray : .pink)
                        }
                    }
                    .disabled(isAlreadyLiked || !userService.canSendLike())
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadUsers() {
        isLoading = true
        currentIndex = 0
        canGoBack = false
        previousUser = nil
        
        Task {
            await userService.fetchUsersForDiscovery()
            isLoading = false
        }
    }
    
    private func refreshUsersAsync() async {
        audioPlayer.stopPlayback()
        currentIndex = 0
        canGoBack = false
        previousUser = nil
        await userService.fetchUsersForDiscovery()
    }
    
    private func skipCurrentUser() {
        guard currentIndex < filteredUsers.count else { return }
        let user = filteredUsers[currentIndex]
        
        // 戻る用に保存
        previousUser = user
        canGoBack = true
        
        Task {
            await userService.skipUser(targetUID: user.uid)
        }
        
        moveToNextUser()
    }
    
    private func goBackToPreviousUser() {
        guard let previous = previousUser else { return }
        
        Task {
            await userService.unskipUser(targetUID: previous.uid)
            await userService.fetchUsersForDiscovery()
            
            if let index = filteredUsers.firstIndex(where: { $0.uid == previous.uid }) {
                currentIndex = index
            }
        }
        
        canGoBack = false
        previousUser = nil
    }
    
    private func sendLikeToCurrentUser() {
        guard currentIndex < filteredUsers.count else { return }
        let user = filteredUsers[currentIndex]
        
        Task {
            let success = await userService.sendLike(toUserID: user.uid)
            if success {
                showLikeAlert = true
                moveToNextUser()
            }
        }
    }
    
    private func moveToNextUser() {
        if currentIndex < filteredUsers.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

// MARK: - Voice Play Button

struct VoicePlayButton: View {
    let audioURL: String
    let duration: Double
    @ObservedObject var audioPlayer: AudioPlayer
    
    private var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL
    }
    
    var body: some View {
        Button(action: {
            if isPlaying {
                audioPlayer.stopPlayback()
            } else {
                if let url = URL(string: audioURL) {
                    audioPlayer.startPlayback(url: url)
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(isPlaying ? "停止" : "ボイスを聴く")
                    .font(.subheadline)
                Text(String(format: "(%.1f秒)", duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.brandPurple)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.brandPurple.opacity(0.1))
            .cornerRadius(20)
        }
    }
}
