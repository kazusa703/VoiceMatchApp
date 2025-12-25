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
    
    // アラート用
    @State private var showReportAlert = false
    @State private var showBlockAlert = false
    
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var currentDate = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // メッセージ一覧表示エリア
            messageListView
            
            Divider()
            
            // 下部の返信ボタン
            replyButtonView
        }
        .navigationTitle(partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert("通報しますか？", isPresented: $showReportAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("不快なコンテンツ", role: .destructive) { reportUser(reason: "不快なコンテンツ") }
            Button("スパム", role: .destructive) { reportUser(reason: "スパム") }
        } message: {
            Text("問題の内容を選択してください。")
        }
        .alert("ブロックしますか？", isPresented: $showBlockAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("ブロックする", role: .destructive) { blockUser() }
        } message: {
            Text("このユーザーとのチャットは削除され、今後表示されなくなります。")
        }
        .onAppear {
            if let matchID = match.id {
                print("DEBUG: ChatDetailView - 監視開始 matchID: \(matchID)")
                messageService.listenToMessages(for: matchID)
            } else {
                print("DEBUG: ChatDetailView - matchIDがありません")
            }
        }
        // ★重要: 画面遷移時のデータクリア処理は削除済み（画面が白くなるのを防ぐため）
        .onReceive(timer) { input in
            currentDate = input
        }
    }
    
    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // メッセージがない場合の表示
                if messageService.currentMessages.isEmpty {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 50)
                        Text("メッセージはまだありません")
                            .foregroundColor(.secondary)
                        Text("ボイスで話しかけてみましょう！")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                } else {
                    // メッセージがある場合
                    LazyVStack(spacing: 20) {
                        ForEach(messageService.currentMessages) { message in
                            MessageRow(
                                message: message,
                                isCurrentUser: message.senderID == userService.currentUserProfile?.uid,
                                audioPlayer: audioPlayer,
                                currentDate: currentDate,
                                onListen: {
                                    if let matchID = match.id, let messageID = message.id {
                                        messageService.incrementListenCount(messageID: messageID, matchID: matchID)
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground)) // LINEっぽい背景色
            // メッセージ更新時に一番下へスクロール
            .onChange(of: messageService.currentMessages.count) { _ in
                if let lastID = messageService.currentMessages.last?.id {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                    }
                }
            }
        }
    }
    
    private var replyButtonView: some View {
        NavigationLink(destination: VoiceRecordingView(
            receiverID: getPartnerID(),
            mode: .chatReply(matchID: match.id ?? "")
        )) {
            HStack {
                Image(systemName: "mic.fill")
                Text("ボイスで返信する").fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(LinearGradient.instaGradient)
            .clipShape(Capsule())
            .padding()
            .shadow(color: Color.brandPurple.opacity(0.3), radius: 5, x: 0, y: 3)
        }
        .background(Color.white)
    }
    
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
                Image(systemName: "ellipsis").foregroundColor(.primary)
            }
        }
    }
    
    private func getPartnerID() -> String {
        guard let myID = userService.currentUserProfile?.uid else { return "" }
        return match.user1ID == myID ? match.user2ID : match.user1ID
    }
    
    private func reportUser(reason: String) {
        let targetID = getPartnerID()
        Task { await userService.reportUser(targetUID: targetID, reason: reason, comment: "", audioURL: nil) }
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

// MARK: - MessageRow (LINE風デザイン修正版)
struct MessageRow: View {
    let message: VoiceMessage
    let isCurrentUser: Bool
    @ObservedObject var audioPlayer: AudioPlayer
    var currentDate: Date
    var onListen: () -> Void
    
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    // 波形の色：自分は薄い黄色/白、相手は紫
    private var waveformColor: Color {
        if isCurrentUser {
            return message.listenCount > 0 ? Color(red: 1.0, green: 0.9, blue: 0.4) : Color.white.opacity(0.7)
        } else {
            return message.listenCount > 0 ? Color.brandPurple.opacity(0.3) : Color.brandPurple
        }
    }
    
    // バブルの背景色
    private var bubbleBackground: some View {
        Group {
            if isCurrentUser {
                LinearGradient.instaGradient // 自分はグラデーション
            } else {
                Color.white // 相手は白（または薄いグレー）
            }
        }
    }
    
    // 文字色
    private var foregroundColor: Color {
        isCurrentUser ? .white : .primary
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 自分なら左側にスペース（右寄せ）
            if isCurrentUser { Spacer() }
            
            // 相手のアバター（必要ならここに追加可能）
            
            // --- メッセージバブル ---
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        // 再生ボタン
                        Button(action: {
                            if audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == message.audioURL {
                                audioPlayer.stopPlayback()
                            } else if let url = URL(string: message.audioURL) {
                                audioPlayer.startPlayback(url: url)
                                if !isCurrentUser { onListen() }
                            }
                        }) {
                            Image(systemName: (audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == message.audioURL) ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 32)) // ボタンサイズ調整
                                .foregroundColor(isCurrentUser ? .white : .brandPurple)
                        }
                        
                        // 波形ビジュアライザー
                        HStack(spacing: 2) {
                            // データがない場合のダミー波形を用意
                            let samples = (message.waveformSamples?.isEmpty == false) ? message.waveformSamples! : [0.4, 0.6, 0.8, 0.5, 0.7, 0.9, 0.6, 0.4, 0.7, 0.5]
                            
                            ForEach(samples.indices.prefix(15), id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(waveformColor)
                                    .frame(width: 3, height: CGFloat(samples[index] * 20 + 5)) // 高さ調整
                            }
                        }
                        
                        // 秒数表示
                        Text("\(Int(message.duration))\"")
                            .font(.caption.bold())
                            .foregroundColor(foregroundColor)
                    }
                    
                    // 再生中のみシークバーを表示
                    if audioPlayer.currentlyPlayingURL == message.audioURL {
                        SeekableProgressBar(audioPlayer: audioPlayer, messageURL: message.audioURL, isCurrentUser: isCurrentUser)
                            .frame(width: 160)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleBackground)
                .clipShape(BubbleShape(isCurrentUser: isCurrentUser))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // --- フッター情報（既読/再生回数/時間） ---
                HStack(spacing: 6) {
                    // 自分のみ：再生回数表示（Pro機能）
                    if isCurrentUser && purchaseManager.isPro && message.listenCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "headphones")
                            Text("\(message.listenCount)")
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.brandPurple)
                    }
                    
                    // 送信時間
                    Text(formatDate(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            
            // 相手なら右側にスペース（左寄せ）
            if !isCurrentUser { Spacer() }
        }
        .padding(.horizontal, 12)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "H:mm"
        return f.string(from: date)
    }
}

// MARK: - シークバー専用View
struct SeekableProgressBar: View {
    @ObservedObject var audioPlayer: AudioPlayer
    let messageURL: String
    let isCurrentUser: Bool
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isCurrentUser ? Color.white.opacity(0.3) : Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(isCurrentUser ? Color.white : Color.brandPurple)
                        .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(radius: 1)
                        .offset(x: progressWidth(in: geometry.size.width) - 6)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let ratio = max(0, min(value.location.x / geometry.size.width, 1))
                            dragValue = Double(ratio) * audioPlayer.duration
                        }
                        .onEnded { value in
                            let ratio = max(0, min(value.location.x / geometry.size.width, 1))
                            audioPlayer.seek(to: Double(ratio) * audioPlayer.duration)
                            isDragging = false
                        }
                )
            }
            .frame(height: 12)
            
            HStack {
                Text(formatTime(isDragging ? dragValue : audioPlayer.currentTime))
                Spacer()
                Text(formatTime(audioPlayer.duration))
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(isCurrentUser ? .white.opacity(0.8) : .secondary)
        }
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard audioPlayer.duration > 0 else { return 0 }
        let time = isDragging ? dragValue : audioPlayer.currentTime
        return totalWidth * CGFloat(time / audioPlayer.duration)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}

// MARK: - BubbleShape (吹き出しの形)
struct BubbleShape: Shape {
    var isCurrentUser: Bool
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: isCurrentUser
                ? [.topLeft, .topRight, .bottomLeft]  // 自分：右下だけ直角（または丸くするなら .bottomRight も含める）
                : [.topLeft, .topRight, .bottomRight], // 相手：左下だけ直角
            cornerRadii: CGSize(width: 18, height: 18)
        )
        return Path(path.cgPath)
    }
}
