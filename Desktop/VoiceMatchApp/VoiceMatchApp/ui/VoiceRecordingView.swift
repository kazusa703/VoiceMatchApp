import SwiftUI
import FirebaseAuth
import Combine

// 録音モードの定義
enum RecordingMode {
    case approach           // 探す画面からの新規アプローチ
    case chatReply(matchID: String) // チャット画面からの返信
}

struct VoiceRecordingView: View {
    let receiverID: String
    var mode: RecordingMode = .approach
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    // 送信状態
    @State private var isSending = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // エフェクト選択
    @State private var selectedEffect: VoiceEffect = .normal
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text(audioRecorder.isRecording ? "録音中..." : "ボイスメッセージ")
                .font(.title2.bold())
            
            // --- 録音・再生状態表示 ---
            VStack {
                if audioRecorder.isRecording {
                    // ★録音中のリアルタイム波形表示
                    WaveformView(samples: audioRecorder.soundSamples)
                        .frame(height: 120)
                        .padding(.horizontal)
                    
                    Text(formatTime(audioRecorder.recordingDuration))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                } else if let _ = audioRecorder.recordingURL {
                    // 録音完了後の表示
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("録音完了")
                            .font(.headline)
                        
                        // エフェクト選択
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(VoiceEffect.allCases, id: \.self) { effect in
                                    VStack {
                                        Image(systemName: effect.icon)
                                            .font(.title2)
                                            .padding(12)
                                            .background(selectedEffect == effect ? Color.brandPurple.opacity(0.2) : Color.gray.opacity(0.1))
                                            .clipShape(Circle())
                                            .foregroundColor(selectedEffect == effect ? .brandPurple : .gray)
                                        
                                        Text(effect.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(selectedEffect == effect ? .brandPurple : .secondary)
                                    }
                                    .onTapGesture {
                                        selectedEffect = effect
                                        audioPlayer.stopPlayback()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Button(action: {
                            if let url = audioRecorder.recordingURL {
                                audioPlayer.startPlayback(url: url)
                            }
                        }) {
                            Label(audioPlayer.isPlaying ? "停止" : "再生して確認", systemImage: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                                .font(.subheadline.bold())
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.brandPurple.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                } else {
                    // 待機状態
                    VStack(spacing: 20) {
                        Image(systemName: "mic.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.brandPurple.opacity(0.2))
                        Text("下のボタンを押して録音を開始")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 250)
            
            Spacer()
            
            // --- 操作ボタン ---
            HStack(spacing: 40) {
                // キャンセル/削除
                if audioRecorder.recordingURL != nil && !audioRecorder.isRecording {
                    Button(action: {
                        audioRecorder.recordingURL = nil
                        selectedEffect = .normal
                    }) {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                
                // 録音・停止
                Button(action: {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                        HapticManager.shared.notification(type: .success)
                    } else {
                        audioRecorder.startRecording()
                        HapticManager.shared.impact(style: .medium)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : Color.brandPurple)
                            .frame(width: 80, height: 80)
                            .shadow(color: (audioRecorder.isRecording ? Color.red : Color.brandPurple).opacity(0.3), radius: 10)
                        
                        Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                // 送信
                if audioRecorder.recordingURL != nil && !audioRecorder.isRecording {
                    Button(action: processAndSend) {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(LinearGradient.instaGradient)
                                .clipShape(Circle())
                        }
                    }
                    .disabled(isSending)
                }
            }
            .padding(.bottom, 40)
        }
        .padding()
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("送信しました") {
                    dismiss()
                }
            }
        }
    }
    
    private func processAndSend() {
        guard let originalURL = audioRecorder.recordingURL else { return }
        isSending = true
        audioPlayer.stopPlayback()
        
        Task {
            do {
                // 1. エフェクト処理（VoiceEffectManager を使用）
                let finalURL = try await VoiceEffectManager.shared.generateProcessedAudio(inputURL: originalURL, effect: selectedEffect)
                let data = try Data(contentsOf: finalURL)
                let duration = audioRecorder.recordingDuration
                
                // 2. モードに応じた送信処理
                switch mode {
                case .approach:
                    try await messageService.sendApproachVoiceMessage(
                        to: receiverID,
                        audioURL: finalURL,
                        duration: duration
                    )
                case .chatReply(let matchID):
                    guard let senderID = userService.currentUserProfile?.uid else { return }
                    try await messageService.sendVoiceMessage(
                        senderID: senderID,
                        receiverID: receiverID,
                        audioData: data,
                        duration: duration,
                        effectName: selectedEffect.rawValue,
                        waveformSamples: audioRecorder.soundSamples
                    )
                    try await userService.incrementMatchCount()
                }
                
                await MainActor.run {
                    isSending = false
                    alertMessage = "メッセージを送信しました！"
                    showAlert = true
                    HapticManager.shared.notification(type: .success)
                }
            } catch {
                print("DEBUG: 送信エラー \(error)")
                await MainActor.run {
                    isSending = false
                    alertMessage = "送信に失敗しました"
                    showAlert = true
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let sec = Int(time)
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d.%d", sec, ms)
    }
}
