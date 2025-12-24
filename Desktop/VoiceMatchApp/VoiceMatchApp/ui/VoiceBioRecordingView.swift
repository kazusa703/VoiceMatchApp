import SwiftUI
import AVFoundation

struct VoiceBioRecordingView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    // 録音・再生用
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    
    @State private var recordedURL: URL?
    @State private var isRecording = false
    @State private var isUploading = false
    @State private var remainingTime: Double = 30.0
    @State private var timer: Timer?
    @State private var progress: Double = 0.0
    
    // エフェクト選択用
    @State private var selectedEffect: VoiceEffect = .normal
    
    var body: some View {
        VStack(spacing: 30) {
            // ヘッダー
            Text("自己紹介ボイス")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            Spacer()
            
            // 1. タイマー表示
            VStack(spacing: 5) {
                Text(String(format: "残り %.1f秒", remainingTime))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(remainingTime < 5 ? .red : .primary)
                
                Text("最大30秒まで録音できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 2. 録音サークル
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(Color.brandPurple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.brandPurple)
                            .frame(width: 90, height: 90)
                            .shadow(color: isRecording ? Color.red.opacity(0.4) : Color.brandPurple.opacity(0.4), radius: 10)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }
            .scaleEffect(recordedURL != nil && !isRecording ? 0.8 : 1.0)
            .animation(.spring(), value: recordedURL)
            
            // 3. 録音完了後の操作エリア
            if recordedURL != nil && !isRecording {
                VStack(spacing: 20) {
                    
                    // エフェクト選択
                    VStack(alignment: .leading, spacing: 10) {
                        Text("声のエフェクト")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
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
                                        // エフェクトを変えたらプレビュー再生を止める
                                        audioPlayer.stopPlayback()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                    
                    // ボタン群
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
                        
                        // プレビュー再生（エフェクト適用前の生音になりますが確認用）
                        Button(action: previewAudio) {
                            VStack {
                                Image(systemName: audioPlayer.isPlaying ? "stop.circle" : "play.circle")
                                    .font(.title2)
                                Text(audioPlayer.isPlaying ? "停止" : "確認")
                                    .font(.caption)
                            }
                            .foregroundColor(.brandPurple)
                        }
                        
                        Spacer()
                        
                        Button(action: saveVoice) {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(width: 100)
                            } else {
                                Text("保存する")
                                    .fontWeight(.bold)
                                    .frame(width: 100)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color.brandPurple)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .disabled(isUploading)
                    }
                    .padding(.horizontal, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding()
        .onDisappear {
            stopTimer()
            audioPlayer.stopPlayback()
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        audioPlayer.stopPlayback()
        isRecording = true
        recordedURL = nil
        remainingTime = 30.0
        progress = 0.0
        audioRecorder.startRecording()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            remainingTime -= 0.1
            progress += 0.1 / 30.0
            
            if remainingTime <= 0 {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        stopTimer()
        audioRecorder.stopRecording()
        
        // ファイル書き込み完了を少し待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let url = audioRecorder.recordingURL {
                print("録音完了: \(url.absoluteString)")
                self.recordedURL = url
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func resetRecording() {
        audioPlayer.stopPlayback()
        recordedURL = nil
        remainingTime = 30.0
        progress = 0.0
        selectedEffect = .normal
    }
    
    private func previewAudio() {
        guard let url = recordedURL else { return }
        
        // ファイルの存在確認
        if !FileManager.default.fileExists(atPath: url.path) {
            print("エラー: 再生しようとしたファイルが存在しません")
            return
        }
        
        if audioPlayer.isPlaying {
            audioPlayer.stopPlayback()
        } else {
            audioPlayer.startPlayback(url: url)
        }
    }
    
    private func saveVoice() {
        guard let originalURL = recordedURL else { return }
        
        // ファイルチェック
        if !FileManager.default.fileExists(atPath: originalURL.path) {
            print("エラー: ファイルが見つかりません")
            return
        }
        
        isUploading = true
        audioPlayer.stopPlayback()
        
        Task {
            do {
                print("エフェクト処理開始: \(selectedEffect.rawValue)")
                // エフェクト処理（WAV -> エフェクト -> m4a変換）
                let processedURL = try await VoiceEffectManager.shared.generateProcessedAudio(inputURL: originalURL, effect: selectedEffect)
                
                print("アップロード開始: \(processedURL.absoluteString)")
                try await userService.uploadBioVoice(audioURL: processedURL)
                
                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
            } catch {
                print("アップロード/変換エラー: \(error)")
                await MainActor.run {
                    isUploading = false
                }
            }
        }
    }
}
