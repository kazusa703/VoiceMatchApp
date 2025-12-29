import SwiftUI
import UserNotifications

struct DiscoveryView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var authService: AuthService
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var isLoading = true
    @State private var showFilter = false
    @State private var showVoiceRecording = false
    @State private var selectedUserForLike: UserProfile?
    
    // スワイプ用
    @State private var offset: CGSize = .zero
    @State private var currentIndex = 0
    
    // カード詳細表示用
    @State private var showDetail = false
    @State private var detailOffset: CGFloat = 0
    
    // 絞り込み条件
    @State private var filterConditions: [String: String] = [:]
    @State private var minCommonPoints: Int = 0
    @State private var commonPointsMode: String = "none"
    @State private var maxDistance: Double = 100
    
    // フィルタリングされたユーザーリスト
    private var filteredUsers: [UserProfile] {
        var users = userService.discoveryUsers
        
        // いいね済みを除外
        users = users.filter { user in
            !(userService.currentUserProfile?.likedUserIDs.contains(user.uid) ?? false)
        }
        
        // 選択式絞り込み条件を適用
        for (key, value) in filterConditions {
            if !value.isEmpty && value != "指定なし" {
                users = users.filter { $0.profileItems[key] == value }
            }
        }
        
        // ハッシュタグフィルター
        if !userService.hashtagFilter.isEmpty {
            users = users.filter { user in
                userService.hashtagFilter.allSatisfy { filterTag in
                    user.hashtags.contains { $0.lowercased().contains(filterTag.lowercased()) }
                }
            }
        }
        
        // 共通点フィルター
        if minCommonPoints > 0 {
            users = users.filter { userService.calculateCommonPoints(with: $0) >= minCommonPoints }
        }
        
        return users
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if filteredUsers.isEmpty {
                    emptyStateView
                } else {
                    cardStackView
                }
            }
            .navigationTitle("探す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterButton
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
            .fullScreenCover(isPresented: $showVoiceRecording) {
                if let user = selectedUserForLike {
                    VoiceLikeRecordingView(targetUser: user) {
                        // 送信成功後
                        moveToNextUser()
                    }
                    .environmentObject(userService)
                }
            }
            .onAppear {
                loadUsers()
            }
            .onDisappear {
                audioPlayer.stopPlayback()
            }
        }
    }
    
    // MARK: - Filter Button
    
    private var filterButton: some View {
        Button(action: { showFilter = true }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.brandPurple)
                
                // フィルターがアクティブな場合
                if !userService.hashtagFilter.isEmpty || !filterConditions.isEmpty || commonPointsMode != "none" {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .offset(x: 5, y: -5)
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("ユーザーを探しています...")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
            
            Button(action: { showFilter = true }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("フィルターを変更")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.brandPurple)
                .cornerRadius(25)
            }
        }
        .padding()
    }
    
    // MARK: - Card Stack View
    
    private var cardStackView: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景カード（次のユーザー）
                if currentIndex + 1 < filteredUsers.count {
                    UserSwipeCardView(
                        user: filteredUsers[currentIndex + 1],
                        commonPoints: userService.calculateCommonPoints(with: filteredUsers[currentIndex + 1]),
                        audioPlayer: audioPlayer,
                        geometry: geometry
                    )
                    .scaleEffect(0.95)
                    .opacity(0.5)
                }
                
                // 現在のカード
                if currentIndex < filteredUsers.count {
                    let user = filteredUsers[currentIndex]
                    
                    UserSwipeCardView(
                        user: user,
                        commonPoints: userService.calculateCommonPoints(with: user),
                        audioPlayer: audioPlayer,
                        geometry: geometry
                    )
                    .offset(x: offset.width, y: 0)
                    .rotationEffect(.degrees(Double(offset.width / 20)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = gesture.translation
                            }
                            .onEnded { gesture in
                                handleSwipe(gesture: gesture, user: user)
                            }
                    )
                    .overlay(swipeOverlay)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 下部のスワイプヒント
            VStack {
                Spacer()
                swipeHintView
            }
        }
        .padding()
    }
    
    // MARK: - Swipe Overlay
    
    private var swipeOverlay: some View {
        ZStack {
            // 右スワイプ（いいね）
            if offset.width > 50 {
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.pink)
                    Text("いいね！")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                }
                .padding(30)
                .background(Color.white.opacity(0.9))
                .cornerRadius(20)
            }
            
            // 左スワイプ（スキップ）
            if offset.width < -50 {
                VStack {
                    Image(systemName: "xmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("スキップ")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
                .padding(30)
                .background(Color.white.opacity(0.9))
                .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Swipe Hint View
    
    private var swipeHintView: some View {
        HStack(spacing: 60) {
            // スキップ
            VStack(spacing: 4) {
                Image(systemName: "arrow.left")
                    .font(.title3)
                Text("スキップ")
                    .font(.caption2)
            }
            .foregroundColor(.gray)
            
            // いいね
            VStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.title3)
                Text("いいね")
                    .font(.caption2)
            }
            .foregroundColor(.pink)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 40)
        .background(Color.white.opacity(0.95))
        .cornerRadius(25)
        .shadow(color: .black.opacity(0.1), radius: 5)
        .padding(.bottom, 20)
    }
    
    // MARK: - Actions
    
    private func handleSwipe(gesture: DragGesture.Value, user: UserProfile) {
        let threshold: CGFloat = 100
        
        withAnimation(.spring()) {
            if gesture.translation.width > threshold {
                // 右スワイプ → いいね → ボイス録音画面へ
                offset = CGSize(width: 500, height: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    selectedUserForLike = user
                    showVoiceRecording = true
                    offset = .zero
                }
            } else if gesture.translation.width < -threshold {
                // 左スワイプ → スキップ
                offset = CGSize(width: -500, height: 0)
                Task {
                    await userService.skipUser(targetUID: user.uid)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    moveToNextUser()
                    offset = .zero
                }
            } else {
                // 戻る
                offset = .zero
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
    
    private func loadUsers() {
        isLoading = true
        currentIndex = 0
        
        Task {
            await userService.fetchHashtagSuggestions()
            await userService.fetchUsersForDiscovery()
            isLoading = false
        }
    }
}

// MARK: - User Swipe Card View

struct UserSwipeCardView: View {
    let user: UserProfile
    let commonPoints: Int
    @ObservedObject var audioPlayer: AudioPlayer
    let geometry: GeometryProxy
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // メインカード部分
                mainCardContent
                    .frame(minHeight: geometry.size.height - 100)
                
                // 詳細情報（下スクロールで表示）
                detailContent
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Main Card Content
    
    private var mainCardContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // アイコン
            UserAvatarView(imageURL: user.iconImageURL, size: 100)
            
            // ユーザー名
            Text(user.username)
                .font(.title)
                .fontWeight(.bold)
            
            // 共通点
            if commonPoints > 0 {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text("\(commonPoints)個の共通点")
                        .font(.subheadline)
                }
                .foregroundColor(.brandPurple)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.brandPurple.opacity(0.1))
                .cornerRadius(20)
            }
            
            // ハッシュタグ（最大3つ）
            if !user.hashtags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(user.hashtags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundColor(.brandPurple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.brandPurple.opacity(0.1))
                            .cornerRadius(15)
                    }
                }
            }
            
            // ボイス再生
            if let introVoice = user.voiceProfiles["introduction"] ?? user.voiceProfiles["naturalVoice"] {
                VoicePlayButton(
                    audioURL: introVoice.audioURL,
                    duration: introVoice.duration,
                    audioPlayer: audioPlayer
                )
            }
            
            Spacer()
            
            // 下スワイプヒント
            VStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .font(.caption)
                Text("下にスクロールで詳細")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            .padding(.bottom, 20)
        }
        .padding()
    }
    
    // MARK: - Detail Content
    
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
                .padding(.horizontal)
            
            // 基本情報
            if !user.publicProfileItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("基本情報")
                        .font(.headline)
                    
                    ForEach(ProfileConstants.selectionItems, id: \.key) { itemDef in
                        if let value = user.publicProfileItems[itemDef.key] {
                            HStack {
                                Text(itemDef.displayName)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(value)
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // 全ハッシュタグ
            if !user.hashtags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ハッシュタグ")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(user.hashtags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .foregroundColor(.brandPurple)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.brandPurple.opacity(0.1))
                                .cornerRadius(15)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // 全ボイスプロフィール
            VStack(alignment: .leading, spacing: 12) {
                Text("ボイス")
                    .font(.headline)
                
                ForEach(VoiceProfileConstants.items) { item in
                    if let voiceData = user.voiceProfiles[item.key] {
                        HStack {
                            Text(item.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button(action: {
                                togglePlayback(audioURL: voiceData.audioURL)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isPlayingURL(voiceData.audioURL) ? "stop.fill" : "play.fill")
                                    Text(String(format: "%.1f秒", voiceData.duration))
                                }
                                .font(.caption)
                                .foregroundColor(.brandPurple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.brandPurple.opacity(0.1))
                                .cornerRadius(15)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer(minLength: 150)
        }
        .padding(.vertical)
    }
    
    private func isPlayingURL(_ url: String) -> Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == url
    }
    
    private func togglePlayback(audioURL: String) {
        if isPlayingURL(audioURL) {
            audioPlayer.stopPlayback()
        } else if let url = URL(string: audioURL) {
            audioPlayer.startPlayback(url: url)
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
            } else if let url = URL(string: audioURL) {
                audioPlayer.startPlayback(url: url)
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
            .padding(.vertical, 12)
            .background(Color.brandPurple.opacity(0.1))
            .cornerRadius(25)
        }
    }
}
