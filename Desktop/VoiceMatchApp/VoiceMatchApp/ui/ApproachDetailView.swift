import SwiftUI
import AVFoundation

struct ApproachDetailView: View {
    let message: Message
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var messageService: MessageService
    @Environment(\.dismiss) var dismiss
    
    @State private var senderProfile: UserProfile?
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var isProcessing = false
    
    // 遷移用フラグと作成されたマッチ情報
    @State private var createdMatch: UserMatch?
    @State private var navigateToChat = false
    
    // 通報・ブロック用のアラートフラグ
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                if let user = senderProfile {
                    VStack(spacing: 15) {
                        UserAvatarView(imageURL: user.profileImageURL, size: 120)
                            .padding(.top, 40)
                        
                        Text(user.username)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 15) {
                            BadgeView(icon: "mappin.and.ellipse", text: user.profileItems["residence"] ?? "未設定")
                            BadgeView(icon: "briefcase", text: user.profileItems["occupation"] ?? "未設定")
                            BadgeView(icon: "person", text: user.profileItems["age"] ?? "未設定")
                        }
                    }
                } else {
                    ProgressView()
                }
                
                Divider().padding()
                
                VStack {
                    Text("届いたメッセージ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: togglePlay) {
                        HStack {
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .font(.title)
                            Text(isPlaying ? "再生停止" : "再生する")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(width: 200)
                        .background(Color.bubbleGray)
                        .foregroundColor(.brandPurple)
                        .cornerRadius(30)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    // 見送る（拒否）ボタン
                    Button(action: declineMatch) {
                        Text("見送る")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // マッチ承認ボタン
                    Button(action: acceptMatch) {
                        if isProcessing {
                            ProgressView().tint(.white)
                        } else {
                            Text("マッチして返信する")
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient.instaGradient)
                                .foregroundColor(.white)
                                .cornerRadius(30)
                                .shadow(radius: 5)
                        }
                    }
                    .disabled(isProcessing)
                }
                .padding()
            }
            
            // マッチ成功時に自動でチャット画面へ飛ばすための隠しリンク
            if let match = createdMatch, let profile = senderProfile {
                NavigationLink(
                    destination: ChatDetailView(match: match, partnerName: profile.username),
                    isActive: $navigateToChat
                ) {
                    EmptyView()
                }
            }
        }
        .onAppear { loadData() }
        .onDisappear { player?.pause() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: { showReportAlert = true }) {
                        Label("通報する", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive, action: { showBlockAlert = true }) {
                        Label("ブロックする", systemImage: "nosign")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("通報しますか？", isPresented: $showReportAlert) {
            Button("不快なコンテンツ", role: .destructive) { reportUser(reason: "不快なコンテンツ") }
            Button("スパム・宣伝", role: .destructive) { reportUser(reason: "スパム") }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("問題の内容を選択してください。")
        }
        .alert("ブロックしますか？", isPresented: $showBlockAlert) {
            Button("ブロックする", role: .destructive) { blockUser() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今後このユーザーのプロフィールやメッセージは一切表示されなくなります。")
        }
    }
    
    // --- ロジック部分 ---
    
    private func loadData() {
        Task {
            senderProfile = try? await userService.fetchOtherUserProfile(uid: message.senderID)
            if let url = URL(string: message.audioURL) {
                player = AVPlayer(url: url)
            }
        }
    }
    
    private func togglePlay() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.seek(to: .zero)
            player.play()
            isPlaying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + message.duration) {
                self.isPlaying = false
            }
        }
    }
    
    private func declineMatch() {
        Task {
            await messageService.declineApproach(message: message)
            await MainActor.run { dismiss() }
        }
    }
    
    private func acceptMatch() {
        isProcessing = true
        Task {
            do {
                if let match = try await messageService.acceptApproach(message: message) {
                    await MainActor.run {
                        self.createdMatch = match
                        self.isProcessing = false
                        self.navigateToChat = true
                    }
                }
            } catch {
                print("DEBUG: マッチ承認失敗: \(error)")
                await MainActor.run { isProcessing = false }
            }
        }
    }
    
    private func reportUser(reason: String) {
        Task {
            await userService.reportUser(
                targetUID: message.senderID,
                reason: reason,
                comment: "",
                audioURL: message.audioURL
            )
            await MainActor.run { dismiss() }
        }
    }
    
    private func blockUser() {
        Task {
            await userService.blockUser(targetUID: message.senderID)
            await MainActor.run { dismiss() }
        }
    }
}

// BadgeViewの定義
struct BadgeView: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
