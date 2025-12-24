import SwiftUI
import Combine
import AVFoundation

struct ChatDetailView: View {
    let match: UserMatch
    let partnerName: String
    
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    @StateObject var audioPlayer = AudioPlayer()
    
    // ★追加: 課金状態などの管理クラス（App全体で注入されている前提）
    // もしコンパイルエラーになる場合は、PreviewやApp.swiftで注入されているか確認してください
    // @EnvironmentObject var purchaseManager: PurchaseManager
    // ※ MessageRow内で使用しますが、ここでの宣言は必須ではありません。
    
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var currentDate = Date()
    
    // アラート用
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 分割したビューを配置
            messageListView
            
            Divider()
            
            // 分割したビューを配置
            replyButtonView
        }
        .navigationTitle(partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // 通報アラート
        .alert("通報しますか？", isPresented: $showReportAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("不快なコンテンツ", role: .destructive) { reportUser(reason: "不快なコンテンツ") }
            Button("スパム", role: .destructive) { reportUser(reason: "スパム") }
        } message: {
            Text("問題の内容を選択してください。")
        }
        // ブロックアラート
        .alert("ブロックしますか？", isPresented: $showBlockAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("ブロックする", role: .destructive) { blockUser() }
        } message: {
            Text("このユーザーとのチャットは削除され、今後表示されなくなります。")
        }
        .onAppear {
            if let matchID = match.id {
                messageService.listenToMessages(for: matchID)
            }
        }
        .onReceive(timer) { input in
            currentDate = input
        }
    }
    
    // MARK: - ビューの分割
    
    // メッセージリスト部分
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(messageService.currentMessages) { message in
                        MessageRow(
                            message: message,
                            isCurrentUser: message.senderID == userService.currentUserProfile?.uid,
                            audioPlayer: audioPlayer,
                            currentDate: currentDate,
                            // ★追加: 再生時のカウントアップ処理
                            onListen: {
                                if let matchID = match.id, let messageID = message.id {
                                    messageService.incrementListenCount(messageID: messageID, matchID: matchID)
                                }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.top)
            }
            .onChange(of: messageService.currentMessages.count) { _ in
                if let lastID = messageService.currentMessages.last?.id {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
        }
    }
    
    // 返信ボタン部分
    private var replyButtonView: some View {
        NavigationLink(destination: VoiceRecordingView(
            receiverID: getPartnerID(),
            mode: .chatReply(matchID: match.id ?? "")
        )) {
            HStack {
                Image(systemName: "mic.fill")
                Text("ボイスで返信する")
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(LinearGradient.instaGradient)
            .clipShape(Capsule())
            .padding()
            .shadow(color: Color.brandPurple.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .background(Color.adaptiveBackground)
    }
    
    // ツールバー部分
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button(role: .destructive, action: { showReportAlert = true }) {
                    Label("通報する", systemImage: "exclamationmark.bubble")
                }
                Button(role: .destructive, action: { showBlockAlert = true }) {
                    Label("ブロックする", systemImage: "nosign")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - ロジック
    
    private func getPartnerID() -> String {
        guard let myID = userService.currentUserProfile?.uid else { return "" }
        return match.user1ID == myID ? match.user2ID : match.user1ID
    }
    
    private func reportUser(reason: String) {
        let targetID = getPartnerID()
        Task {
            await userService.reportUser(
                targetUID: targetID,
                reason: reason,
                comment: "",
                audioURL: nil
            )
        }
    }
    
    private func blockUser() {
        let targetID = getPartnerID()
        Task {
            await userService.blockUser(targetUID: targetID)
            guard let myUID = userService.currentUserProfile?.uid else { return }
            let blockedIDs = (userService.currentUserProfile?.blockedUserIDs ?? []) + [targetID]
            await messageService.fetchMatches(for: myUID, blockedUserIDs: blockedIDs)
            dismiss()
        }
    }
}

// MARK: - MessageRow
struct MessageRow: View {
    let message: VoiceMessage
    let isCurrentUser: Bool
    @ObservedObject var audioPlayer: AudioPlayer
    var currentDate: Date
    
    // ★追加: 再生時に実行するクロージャ
    var onListen: () -> Void
    
    // ★追加: 課金状態を確認するためのEnvironmentObject
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        HStack(alignment: .bottom) {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                // ボイスバブル本体
                HStack(spacing: 12) {
                    Button(action: {
                        if audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == message.audioURL {
                            audioPlayer.stopPlayback()
                        } else if let url = URL(string: message.audioURL) {
                            audioPlayer.startPlayback(url: url)
                            
                            // ★相手が聴いた場合のみカウントを増やす（自分のはカウントしない）
                            if !isCurrentUser {
                                onListen()
                            }
                        }
                    }) {
                        Image(systemName: (audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == message.audioURL) ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(isCurrentUser ? .white : .brandPurple)
                    }
                    
                    // 波形表示
                    HStack(spacing: 2) {
                        if let samples = message.waveformSamples, !samples.isEmpty {
                            ForEach(samples.indices, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(isCurrentUser ? Color.white.opacity(0.8) : Color.brandPurple.opacity(0.6))
                                    .frame(width: 3, height: CGFloat(samples[index] * 25))
                            }
                        } else {
                            ForEach(0..<15) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(isCurrentUser ? Color.white.opacity(0.6) : Color.brandPurple.opacity(0.4))
                                    .frame(width: 3, height: CGFloat.random(in: 10...25))
                            }
                        }
                    }
                    
                    Text("\(Int(message.duration))\"")
                        .font(.caption.bold())
                        .foregroundColor(isCurrentUser ? .white : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isCurrentUser ? AnyShapeStyle(LinearGradient.instaGradient) : AnyShapeStyle(Color.bubbleGray))
                .clipShape(BubbleShape(isCurrentUser: isCurrentUser))
                
                // ★追加: 再生回数表示 (Proユーザーのみ、かつ自分のメッセージのみ表示)
                HStack(spacing: 8) {
                    if isCurrentUser && purchaseManager.isPro {
                        HStack(spacing: 2) {
                            Image(systemName: message.listenCount > 0 ? "headphones" : "headphones.slash")
                            Text(message.listenCount > 0 ? "\(message.listenCount)回再生済み" : "未再生")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.brandPurple)
                    }
                    
                    // エフェクト表示がある場合はここに含める
                    if let effect = message.effectUsed, effect != "地声" {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                            Text(effect)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.brandPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandPurple.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Text(formatDate(message.timestamp)).font(.caption2).foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
            }
            if !isCurrentUser { Spacer() }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

struct BubbleShape: Shape {
    var isCurrentUser: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight],
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}
