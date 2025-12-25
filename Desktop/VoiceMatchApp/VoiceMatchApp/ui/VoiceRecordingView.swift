import SwiftUI
import FirebaseAuth
import AVFoundation

struct VoiceRecordingView: View {
    let receiverID: String
    var mode: RecordingMode = .approach
    
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @State private var isSending = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedEffect: VoiceEffect = .normal

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text(audioRecorder.isRecording ? "録音中..." : "ボイスメッセージ").font(.title2.bold())
            
            VStack {
                if audioRecorder.isRecording {
                    WaveformView(samples: audioRecorder.soundSamples).frame(height: 100)
                    Text(formatTime(audioRecorder.recordingDuration))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "mic.circle").font(.system(size: 80)).foregroundColor(.brandPurple.opacity(0.2))
                }
            }
            .frame(height: 200)

            HStack(spacing: 40) {
                Button(action: {
                    audioRecorder.isRecording ? audioRecorder.stopRecording() : audioRecorder.startRecording()
                }) {
                    Circle().fill(audioRecorder.isRecording ? Color.red : Color.brandPurple).frame(width: 80, height: 80)
                        .overlay(Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill").font(.title).foregroundColor(.white))
                }
                
                if audioRecorder.recordingURL != nil && !audioRecorder.isRecording {
                    Button(action: processAndSend) {
                        if isSending { ProgressView().tint(.white) }
                        else { Image(systemName: "paperplane.fill").foregroundColor(.white).padding().background(LinearGradient.instaGradient).clipShape(Circle()) }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear { setupAudioSession() }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") { if alertMessage.contains("送信しました") { dismiss() } }
        }
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch { print("Audio Error: \(error)") }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let sec = Int(time)
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d.%d", sec, ms)
    }
    
    private func processAndSend() {
        guard let url = audioRecorder.recordingURL else { return }
        isSending = true
        Task {
            do {
                switch mode {
                case .approach:
                    try await messageService.sendApproachVoiceMessage(to: receiverID, audioURL: url, duration: audioRecorder.recordingDuration, userService: userService)
                case .chatReply(_):
                    let data = try Data(contentsOf: url)
                    try await messageService.sendVoiceMessage(senderID: Auth.auth().currentUser?.uid ?? "", receiverID: receiverID, audioData: data, duration: audioRecorder.recordingDuration, effectName: selectedEffect.rawValue, waveformSamples: audioRecorder.soundSamples)
                }
                await MainActor.run { isSending = false; alertMessage = "メッセージを送信しました！"; showAlert = true }
            } catch {
                await MainActor.run { isSending = false; alertMessage = "エラー: \(error.localizedDescription)"; showAlert = true }
            }
        }
    }
}
