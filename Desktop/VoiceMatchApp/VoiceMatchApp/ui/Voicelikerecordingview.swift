import SwiftUI

struct VoiceLikeRecordingView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    let targetUser: UserProfile
    var onSuccess: () -> Void
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var recordingState: RecordingState = .ready
    @State private var recordedURL: URL?
    @State private var recordedDuration: Double = 0
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 録音時間計測用タイマー
    @State private var recordingTime: Double = 0
    @State private var recordingTimer: Timer?
    
    enum RecordingState {
        case ready
        case recording
        case recorded
        case playing
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 相手のプロフィール
                targetUserSection
                
                Spacer()
                
                // 録音UI
                recordingSection
                
                Spacer()
                
                // 送信ボタン
                if recordingState == .recorded || recordingState == .playing {
                    sendButton
                }
                
                // ヒント
                hintText
            }
            .padding()
            .navigationTitle("ボイスを送る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        stopRecordingTimer()
                        audioRecorder.stopRecording()
                        audioPlayer.stopPlayback()
                        dismiss()
                    }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onDisappear {
                stopRecordingTimer()
                audioRecorder.stopRecording()
                audioPlayer.stopPlayback()
            }
        }
    }
    
    // MARK: - Target User Section
    
    private var targetUserSection: some View {
        VStack(spacing: 12) {
            UserAvatarView(imageURL: targetUser.iconImageURL, size: 80)
            
            Text(targetUser.username)
                .font(.title2)
                .fontWeight(.bold)
            
            Text("さんにボイスを送りましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Recording Section
    
    private var recordingSection: some View {
        VStack(spacing: 24) {
            // 録音時間表示
            if recordingState == .recording {
                Text(formatTime(recordingTime))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.red)
            } else if recordedDuration > 0 {
                Text(formatTime(recordedDuration))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundColor(.brandPurple)
            }
            
            // 録音ボタン
            Button(action: handleRecordButton) {
                ZStack {
                    Circle()
                        .fill(recordingState == .recording ? Color.red : Color.brandPurple)
                        .frame(width: 100, height: 100)
                        .shadow(color: (recordingState == .recording ? Color.red : Color.brandPurple).opacity(0.3), radius: 10)
                    
                    if recordingState == .recording {
                        // 録音中は停止アイコン
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    } else {
                        // それ以外はマイクアイコン
                        Image(systemName: "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // 状態に応じたテキスト
            Text(recordingStateText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 再生ボタン（録音後）
            if recordingState == .recorded || recordingState == .playing {
                Button(action: handlePlayButton) {
                    HStack {
                        Image(systemName: recordingState == .playing ? "stop.fill" : "play.fill")
                        Text(recordingState == .playing ? "停止" : "確認再生")
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandPurple)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.brandPurple.opacity(0.1))
                    .cornerRadius(25)
                }
            }
            
            // 録り直しボタン
            if recordingState == .recorded || recordingState == .playing {
                Button(action: resetRecording) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("録り直す")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Send Button
    
    private var sendButton: some View {
        Button(action: sendVoiceLike) {
            HStack {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "heart.fill")
                    Text("ボイスを送っていいねする")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
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
        .disabled(isSending)
        .padding(.horizontal)
    }
    
    // MARK: - Hint Text
    
    private var hintText: some View {
        VStack(spacing: 8) {
            Text("💡 ヒント")
                .font(.caption)
                .fontWeight(.bold)
            Text("自己紹介や、共通点について話すと\n相手に興味を持ってもらいやすくなります")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(15)
        .padding(.bottom, 20)
    }
    
    // MARK: - Computed Properties
    
    private var recordingStateText: String {
        switch recordingState {
        case .ready:
            return "タップして録音開始"
        case .recording:
            return "録音中...タップして停止"
        case .recorded:
            return "録音完了"
        case .playing:
            return "再生中..."
        }
    }
    
    // MARK: - Timer Functions
    
    private func startRecordingTimer() {
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Actions
    
    private func handleRecordButton() {
        switch recordingState {
        case .ready, .recorded, .playing:
            // 録音開始
            audioPlayer.stopPlayback()
            audioRecorder.startRecording()
            startRecordingTimer()
            recordingState = .recording
            
        case .recording:
            // 録音停止
            stopRecordingTimer()
            audioRecorder.stopRecording()
            if let url = audioRecorder.recordingURL {
                recordedURL = url
                recordedDuration = recordingTime
            }
            recordingState = .recorded
        }
    }
    
    private func handlePlayButton() {
        guard let url = recordedURL else { return }
        
        if recordingState == .playing {
            audioPlayer.stopPlayback()
            recordingState = .recorded
        } else {
            audioPlayer.startPlayback(url: url)
            recordingState = .playing
            
            // 再生終了時にstateを戻す
            DispatchQueue.main.asyncAfter(deadline: .now() + recordedDuration + 0.5) {
                if recordingState == .playing {
                    recordingState = .recorded
                }
            }
        }
    }
    
    private func resetRecording() {
        audioPlayer.stopPlayback()
        audioRecorder.resetRecording()
        recordedURL = nil
        recordedDuration = 0
        recordingTime = 0
        recordingState = .ready
    }
    
    private func sendVoiceLike() {
        guard let url = recordedURL else { return }
        
        isSending = true
        
        Task {
            let success = await userService.sendVoiceLike(
                toUserID: targetUser.uid,
                voiceURL: url,
                duration: recordedDuration
            )
            
            isSending = false
            
            if success {
                dismiss()
                onSuccess()
            } else {
                errorMessage = "送信に失敗しました。もう一度お試しください。"
                showError = true
            }
        }
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, milliseconds)
    }
}
