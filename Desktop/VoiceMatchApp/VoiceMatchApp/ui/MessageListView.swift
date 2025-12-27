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
                    Text("届いた").tag(MessageSection.received)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // コンテンツ
                switch messageService.selectedSection {
                case .matches:
                    matchesListView
                case .received:
                    receivedLikesListView
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
    
    // MARK: - 受け取ったいいね一覧
    
    private var receivedLikesListView: some View {
        Group {
            if userService.receivedLikes.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("まだいいねは届いていません")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(userService.receivedLikes) { like in
                        ReceivedLikeRow(like: like)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - マッチ行

struct MatchRow: View {
    let match: UserMatch
    let currentUID: String
    
    @State private var partnerProfile: UserProfile?
    @EnvironmentObject var userService: UserService
    
    private var partnerID: String {
        match.user1ID == currentUID ? match.user2ID : match.user1ID
    }
    
    var body: some View {
        HStack {
            UserAvatarView(imageURL: partnerProfile?.iconImageURL, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(partnerProfile?.username ?? "読み込み中...")
                    .font(.headline)
                
                Text("ボイスメッセージでやり取り中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(match.lastMessageDate, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .task {
            partnerProfile = try? await userService.fetchOtherUserProfile(uid: partnerID)
        }
    }
}

// MARK: - 受け取ったいいね行

struct ReceivedLikeRow: View {
    let like: Like
    
    @State private var senderProfile: UserProfile?
    @State private var isProcessing = false
    @State private var showUserDetail = false
    
    @EnvironmentObject var userService: UserService
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        HStack {
            // アイコン（タップで詳細）
            Button(action: { showUserDetail = true }) {
                UserAvatarView(imageURL: senderProfile?.iconImageURL, size: 50)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(senderProfile?.username ?? "読み込み中...")
                    .font(.headline)
                
                Text("いいねが届いています")
                    .font(.caption)
                    .foregroundColor(.brandPurple)
            }
            
            Spacer()
            
            // 承認・拒否ボタン
            HStack(spacing: 12) {
                Button(action: declineLike) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: acceptLike) {
                    if isProcessing {
                        ProgressView()
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(LinearGradient.instaGradient)
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing)
            }
        }
        .task {
            senderProfile = try? await userService.fetchOtherUserProfile(uid: like.fromUserID)
        }
        .sheet(isPresented: $showUserDetail) {
            if let profile = senderProfile {
                NavigationView {
                    LikeUserDetailView(
                        user: profile,
                        commonPoints: userService.calculateCommonPoints(with: profile),
                        onAccept: acceptLike,
                        onDecline: declineLike
                    )
                }
            }
        }
    }
    
    private func acceptLike() {
        isProcessing = true
        Task {
            _ = await userService.acceptLike(fromUserID: like.fromUserID)
            isProcessing = false
        }
    }
    
    private func declineLike() {
        Task {
            await userService.declineLike(fromUserID: like.fromUserID)
        }
    }
}

// MARK: - いいねを送ってきたユーザーの詳細

struct LikeUserDetailView: View {
    let user: UserProfile
    let commonPoints: Int
    var onAccept: () -> Void
    var onDecline: () -> Void
    
    @StateObject private var audioPlayer = AudioPlayer()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // アイコンとユーザー名
                HStack(spacing: 16) {
                    UserAvatarView(imageURL: user.iconImageURL, size: 80)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(user.username)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                            Text("共通点 \(commonPoints)個")
                                .font(.subheadline)
                                .foregroundColor(.brandPurple)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                .padding(.top)
                
                // ボイス一覧
                VStack(alignment: .leading, spacing: 16) {
                    Text("ボイス")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(VoiceProfileConstants.items) { item in
                        if let voiceData = user.voiceProfiles[item.key] {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(String(format: "%.1f秒", voiceData.duration))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    if audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == voiceData.audioURL {
                                        audioPlayer.stopPlayback()
                                    } else {
                                        if let url = URL(string: voiceData.audioURL) {
                                            audioPlayer.startPlayback(url: url)
                                        }
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: (audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == voiceData.audioURL) ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.title2)
                                        Text((audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == voiceData.audioURL) ? "停止" : "再生")
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
                    }
                }
                .padding(.vertical)
                .background(Color.white)
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Button(action: {
                    onDecline()
                    dismiss()
                }) {
                    Text("スキップ")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(30)
                }
                
                Button(action: {
                    onAccept()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("マッチする")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.instaGradient)
                    .cornerRadius(30)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle(user.username)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .onDisappear {
            audioPlayer.stopPlayback()
        }
    }
}
