import SwiftUI
import AVFoundation
import FirebaseAuth

struct ChatDetailView: View {
    let match: UserMatch
    let partnerName: String
    
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var purchaseManager: PurchaseManager
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var showVoiceRecorder = false
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var partnerProfile: UserProfile?
    
    private var currentUID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var partnerID: String {
        match.user1ID == currentUID ? match.user2ID : match.user1ID
    }
    
    private var matchID: String {
        match.id ?? [match.user1ID, match.user2ID].sorted().joined(separator: "_")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // メッセージ一覧
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messageService.currentMessages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "waveform.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("ボイスメッセージを送ってみましょう！")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(messageService.currentMessages) { message in
                                VoiceBubble(
                                    message: message,
                                    isFromMe: message.senderID == currentUID,
                                    audioPlayer: audioPlayer
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messageService.currentMessages.count) { _ in
                    if let lastID = messageService.currentMessages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // 録音ボタン
            VStack(spacing: 8) {
                Button(action: { showVoiceRecorder = true }) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                        Text("ボイスメッセージを録音")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient.instaGradient)
                    .cornerRadius(25)
                }
                .padding(.horizontal)
                
                Text("最大1分まで録音できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            .background(Color.white)
        }
        .navigationTitle(partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: { showReportSheet = true }) {
                        Label("通報する", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive, action: { showBlockAlert = true }) {
                        Label("ブロックする", systemImage: "nosign")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            messageService.listenToMessages(for: matchID)
            Task {
                partnerProfile = try? await userService.fetchOtherUserProfile(uid: partnerID)
            }
        }
        .onDisappear {
            messageService.clearMessages()
            audioPlayer.stopPlayback()
        }
        .sheet(isPresented: $showVoiceRecorder) {
            ChatVoiceRecorderView(matchID: matchID, isPro: purchaseManager.isPro)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(targetUID: partnerID, audioURL: nil)
        }
        .alert("ブロックしますか？", isPresented: $showBlockAlert) {
            Button("ブロックする", role: .destructive) {
                Task { await userService.blockUser(targetUID: partnerID) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("今後このユーザーのメッセージは表示されなくなります。")
        }
    }
}

// MARK: - ボイスバブル

struct VoiceBubble: View {
    let message: VoiceMessage
    let isFromMe: Bool
    @ObservedObject var audioPlayer: AudioPlayer
    
    private var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == message.audioURL
    }
    
    var body: some View {
        HStack {
            if isFromMe { Spacer() }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                // ボイスメッセージ
                if let url = URL(string: message.audioURL) {
                    Button(action: {
                        if isPlaying {
                            audioPlayer.stopPlayback()
                        } else {
                            audioPlayer.startPlayback(url: url)
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                .font(.title3)
                            
                            // 波形表示（簡易）
                            HStack(spacing: 2) {
                                ForEach(0..<12, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isFromMe ? Color.white.opacity(0.7) : Color.brandPurple.opacity(0.7))
                                        .frame(width: 3, height: CGFloat.random(in: 8...20))
                                }
                            }
                            
                            Text(String(format: "%.1f秒", message.duration))
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isFromMe ? Color.brandPurple : Color.bubbleGray)
                        .foregroundColor(isFromMe ? .white : .primary)
                        .cornerRadius(20)
                    }
                }
                
                // エフェクト表示
                HStack(spacing: 4) {
                    if let effect = message.effectUsed, effect != "normal" {
                        if let effectDef = VoiceEffectConstants.getEffect(by: effect) {
                            Image(systemName: effectDef.icon)
                                .font(.caption2)
                            Text(effectDef.displayName)
                                .font(.caption2)
                        }
                    }
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            if !isFromMe { Spacer() }
        }
    }
}

// MARK: - チャット用ボイス録音画面

struct ChatVoiceRecorderView: View {
    let matchID: String
    let isPro: Bool
    
    @EnvironmentObject var messageService: MessageService
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var effectManager = VoiceEffectManager.shared
    
    @State private var recordingDuration: Double = 0
    @State private var timer: Timer?
    @State private var isProcessing = false
    @State private var isSending = false
    @State private var processedURL: URL?
    @State private var showEffectSettings = false
    
    @State private var selectedEffect: VoiceEffectDefinition?
    
    private let maxDuration: Double = 60.0
    
    var availableEffects: [VoiceEffectDefinition] {
        VoiceEffectConstants.getEffectsForUser(isPro: isPro)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("ボイスメッセージ")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                Text("最大60秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 録音時間
                Text(String(format: "%.1f秒", recordingDuration))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(recordingDuration > 50 ? .red : .primary)
                
                // 録音ボタン
                Button(action: toggleRecording) {
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.red : Color.brandPurple)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
                
                Spacer()
                
                // エフェクト選択
                if audioRecorder.recordingURL != nil && !audioRecorder.isRecording {
                    VStack(spacing: 12) {
                        Text("エフェクト")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableEffects) { effect in
                                    EffectButton(
                                        effect: effect,
                                        isSelected: selectedEffect?.key == effect.key,
                                        onSelect: { selectEffect(effect) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Pro用調整バー
                        if isPro && selectedEffect != nil {
                            Button("詳細調整") {
                                showEffectSettings = true
                            }
                            .font(.caption)
                            .foregroundColor(.brandPurple)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // 操作ボタン
                    HStack(spacing: 20) {
                        Button(action: resetRecording) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                Text("撮り直す")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: previewAudio) {
                            VStack {
                                Image(systemName: audioPlayer.isPlaying ? "stop.circle" : "play.circle")
                                    .font(.title2)
                                Text(audioPlayer.isPlaying ? "停止" : "試聴")
                                    .font(.caption)
                            }
                            .foregroundColor(.brandPurple)
                        }
                        
                        Spacer()
                        
                        Button(action: sendVoice) {
                            if isSending || isProcessing {
                                ProgressView()
                            } else {
                                VStack {
                                    Image(systemName: "paperplane.fill")
                                        .font(.title2)
                                    Text("送信")
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                            }
                        }
                        .disabled(isSending || isProcessing)
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        audioPlayer.stopPlayback()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEffectSettings) {
                EffectSettingsView(effectManager: effectManager)
            }
            .onAppear {
                selectedEffect = VoiceEffectConstants.freeEffects.first
            }
            .onDisappear {
                timer?.invalidate()
                audioPlayer.stopPlayback()
            }
        }
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            timer?.invalidate()
        } else {
            audioPlayer.stopPlayback()
            recordingDuration = 0
            processedURL = nil
            audioRecorder.startRecording()
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
                if recordingDuration >= maxDuration {
                    audioRecorder.stopRecording()
                    timer?.invalidate()
                }
            }
        }
    }
    
    private func resetRecording() {
        audioPlayer.stopPlayback()
        recordingDuration = 0
        processedURL = nil
    }
    
    private func selectEffect(_ effect: VoiceEffectDefinition) {
        selectedEffect = effect
        effectManager.selectEffect(effect)
        processedURL = nil
    }
    
    private func previewAudio() {
        if audioPlayer.isPlaying {
            audioPlayer.stopPlayback()
            return
        }
        
        if let effect = selectedEffect, effect.key != "normal" {
            guard let originalURL = audioRecorder.recordingURL else { return }
            
            if let processed = processedURL {
                audioPlayer.startPlayback(url: processed)
            } else {
                isProcessing = true
                effectManager.applyEffect(to: originalURL) { result in
                    isProcessing = false
                    switch result {
                    case .success(let url):
                        processedURL = url
                        audioPlayer.startPlayback(url: url)
                    case .failure(let error):
                        print("エフェクト処理エラー: \(error)")
                    }
                }
            }
        } else {
            if let url = audioRecorder.recordingURL {
                audioPlayer.startPlayback(url: url)
            }
        }
    }
    
    private func sendVoice() {
        guard recordingDuration > 0 else { return }
        
        let effectKey = selectedEffect?.key
        
        if let effect = selectedEffect, effect.key != "normal" {
            guard let originalURL = audioRecorder.recordingURL else { return }
            
            if let processed = processedURL {
                sendProcessedVoice(url: processed, effectKey: effectKey)
            } else {
                isProcessing = true
                effectManager.applyEffect(to: originalURL) { result in
                    isProcessing = false
                    switch result {
                    case .success(let url):
                        sendProcessedVoice(url: url, effectKey: effectKey)
                    case .failure(let error):
                        print("エフェクト処理エラー: \(error)")
                    }
                }
            }
        } else {
            if let url = audioRecorder.recordingURL {
                sendProcessedVoice(url: url, effectKey: effectKey)
            }
        }
    }
    
    private func sendProcessedVoice(url: URL, effectKey: String?) {
        guard let data = try? Data(contentsOf: url) else { return }
        
        isSending = true
        Task {
            do {
                try await messageService.sendVoiceMessage(
                    matchID: matchID,
                    senderID: Auth.auth().currentUser?.uid ?? "",
                    audioData: data,
                    duration: recordingDuration,
                    effectUsed: effectKey
                )
                dismiss()
            } catch {
                print("送信エラー: \(error)")
                isSending = false
            }
        }
    }
}
