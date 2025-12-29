import SwiftUI

struct MessageListView: View {
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var userService: UserService
    
    var body: some View {
        NavigationView {
            VStack {
                // サブタブ切り替え
                Picker("表示", selection: $messageService.selectedSection) {
                    Text("マッチ中").tag(MessageSection.matches)
                    
                    // 届いたいいねの件数をバッジ表示
                    HStack {
                        Text("届いた")
                        if userService.receivedLikes.count > 0 {
                            Text("\(userService.receivedLikes.count)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink)
                                .cornerRadius(10)
                        }
                    }.tag(MessageSection.received)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // コンテンツ
                switch messageService.selectedSection {
                case .matches:
                    matchesListView
                case .received:
                    receivedLikesCardView
                }
            }
            .navigationTitle("メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    if let uid = userService.currentUserProfile?.uid {
                        await messageService.fetchMatches(for: uid)
                    }
                    await userService.fetchReceivedLikes()
                }
            }
        }
    }
    
    // MARK: - マッチ一覧
    
    private var matchesListView: some View {
        Group {
            if messageService.matches.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("まだマッチした相手がいません")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(messageService.matches) { match in
                        NavigationLink(destination: ChatDetailView(
                            match: match,
                            partnerName: "チャット"
                        )) {
                            MatchRow(match: match, currentUID: userService.currentUserProfile?.uid ?? "")
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - 受け取ったいいね（カード形式）
    
    private var receivedLikesCardView: some View {
        Group {
            if userService.receivedLikes.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("まだいいねは届いていません")
                        .foregroundColor(.secondary)
                    Text("探すタブで気になる人にいいねしてみましょう")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ReceivedLikesCardStack()
                    .environmentObject(userService)
            }
        }
    }
}

// MARK: - マッチ行

struct MatchRow: View {
    let match: UserMatch
    let currentUID: String
    
    @EnvironmentObject var userService: UserService
    @State private var partnerProfile: UserProfile?
    
    private var partnerID: String {
        match.user1ID == currentUID ? match.user2ID : match.user1ID
    }
    
    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(imageURL: partnerProfile?.iconImageURL, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(partnerProfile?.username ?? "読み込み中...")
                    .font(.headline)
                
                Text("マッチ中")
                    .font(.caption)
                    .foregroundColor(.brandPurple)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .task {
            partnerProfile = try? await userService.fetchOtherUserProfile(uid: partnerID)
        }
    }
}

// MARK: - 受け取ったいいねカードスタック

struct ReceivedLikesCardStack: View {
    @EnvironmentObject var userService: UserService
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var currentIndex = 0
    @State private var offset: CGSize = .zero
    @State private var showMatchAlert = false
    @State private var matchedUser: UserProfile?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景カード
                if currentIndex + 1 < userService.receivedLikes.count {
                    ReceivedLikeCard(
                        like: userService.receivedLikes[currentIndex + 1],
                        audioPlayer: audioPlayer,
                        geometry: geometry
                    )
                    .scaleEffect(0.95)
                    .opacity(0.5)
                }
                
                // 現在のカード
                if currentIndex < userService.receivedLikes.count {
                    let like = userService.receivedLikes[currentIndex]
                    
                    ReceivedLikeCard(
                        like: like,
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
                                handleSwipe(gesture: gesture, like: like)
                            }
                    )
                    .overlay(swipeOverlay)
                }
                
                // カウンター
                VStack {
                    HStack {
                        Spacer()
                        Text("\(currentIndex + 1) / \(userService.receivedLikes.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(15)
                    }
                    Spacer()
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 下部のスワイプヒント
            VStack {
                Spacer()
                swipeHintView
            }
        }
        .padding()
        .alert("マッチしました！🎉", isPresented: $showMatchAlert) {
            Button("メッセージを送る") {
                // メッセージタブに切り替え
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let user = matchedUser {
                Text("\(user.username)さんとマッチしました！\nメッセージを送ってみましょう")
            }
        }
        .onDisappear {
            audioPlayer.stopPlayback()
        }
    }
    
    // MARK: - Swipe Overlay
    
    private var swipeOverlay: some View {
        ZStack {
            // 右スワイプ（承認）
            if offset.width > 50 {
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.pink)
                    Text("承認！")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                }
                .padding(30)
                .background(Color.white.opacity(0.9))
                .cornerRadius(20)
            }
            
            // 左スワイプ（拒否）
            if offset.width < -50 {
                VStack {
                    Image(systemName: "xmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("拒否")
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
            VStack(spacing: 4) {
                Image(systemName: "arrow.left")
                    .font(.title3)
                Text("拒否")
                    .font(.caption2)
            }
            .foregroundColor(.gray)
            
            VStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.title3)
                Text("承認")
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
    
    private func handleSwipe(gesture: DragGesture.Value, like: Like) {
        let threshold: CGFloat = 100
        
        withAnimation(.spring()) {
            if gesture.translation.width > threshold {
                // 右スワイプ → 承認
                offset = CGSize(width: 500, height: 0)
                Task {
                    if let match = await userService.acceptLike(fromUserID: like.fromUserID) {
                        if let user = try? await userService.fetchOtherUserProfile(uid: like.fromUserID) {
                            matchedUser = user
                            showMatchAlert = true
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    moveToNextLike()
                    offset = .zero
                }
            } else if gesture.translation.width < -threshold {
                // 左スワイプ → 拒否
                offset = CGSize(width: -500, height: 0)
                Task {
                    await userService.declineLike(fromUserID: like.fromUserID)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    moveToNextLike()
                    offset = .zero
                }
            } else {
                offset = .zero
            }
        }
    }
    
    private func moveToNextLike() {
        if currentIndex < userService.receivedLikes.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
    }
}

// MARK: - 受け取ったいいねカード

struct ReceivedLikeCard: View {
    let like: Like
    @ObservedObject var audioPlayer: AudioPlayer
    let geometry: GeometryProxy
    
    @EnvironmentObject var userService: UserService
    @State private var senderProfile: UserProfile?
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // メインカード部分
                mainCardContent
                    .frame(minHeight: geometry.size.height - 100)
                
                // 詳細情報
                if let profile = senderProfile {
                    detailContent(profile: profile)
                }
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .task {
            senderProfile = try? await userService.fetchOtherUserProfile(uid: like.fromUserID)
        }
    }
    
    // MARK: - Main Card Content
    
    private var mainCardContent: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // アイコン
            UserAvatarView(imageURL: senderProfile?.iconImageURL, size: 100)
            
            // ユーザー名
            Text(senderProfile?.username ?? "読み込み中...")
                .font(.title)
                .fontWeight(.bold)
            
            // 共通点
            if let profile = senderProfile {
                let commonPoints = userService.calculateCommonPoints(with: profile)
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
            }
            
            // ボイスいいね再生（大きめボタン）
            if let voiceURL = like.voiceURL, let duration = like.voiceDuration {
                VStack(spacing: 8) {
                    Text("🎤 ボイスメッセージが届いています")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        toggleVoicePlayback(urlString: voiceURL)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: isPlayingVoice(urlString: voiceURL) ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 40))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isPlayingVoice(urlString: voiceURL) ? "停止" : "ボイスを聴く")
                                    .font(.headline)
                                Text(String(format: "%.1f秒", duration))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.pink, .brandPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                    }
                }
                .padding(.vertical, 10)
            }
            
            // ハッシュタグ
            if let profile = senderProfile, !profile.hashtags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(profile.hashtags.prefix(3), id: \.self) { tag in
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
    
    private func detailContent(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Divider()
                .padding(.horizontal)
            
            // 基本情報
            if !profile.publicProfileItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("基本情報")
                        .font(.headline)
                    
                    ForEach(ProfileConstants.selectionItems, id: \.key) { itemDef in
                        if let value = profile.publicProfileItems[itemDef.key] {
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
            if !profile.hashtags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("ハッシュタグ")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(profile.hashtags, id: \.self) { tag in
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
            
            // ボイスプロフィール
            VStack(alignment: .leading, spacing: 12) {
                Text("ボイスプロフィール")
                    .font(.headline)
                
                ForEach(VoiceProfileConstants.items) { item in
                    if let voiceData = profile.voiceProfiles[item.key] {
                        HStack {
                            Text(item.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button(action: {
                                toggleProfileVoice(audioURL: voiceData.audioURL)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isPlayingProfileVoice(voiceData.audioURL) ? "stop.fill" : "play.fill")
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
    
    // MARK: - Voice Playback
    
    private func isPlayingVoice(urlString: String) -> Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == urlString
    }
    
    private func toggleVoicePlayback(urlString: String) {
        if isPlayingVoice(urlString: urlString) {
            audioPlayer.stopPlayback()
        } else if let url = URL(string: urlString) {
            audioPlayer.startPlayback(url: url)
        }
    }
    
    private func isPlayingProfileVoice(_ url: String) -> Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == url
    }
    
    private func toggleProfileVoice(audioURL: String) {
        if isPlayingProfileVoice(audioURL) {
            audioPlayer.stopPlayback()
        } else if let url = URL(string: audioURL) {
            audioPlayer.startPlayback(url: url)
        }
    }
}
