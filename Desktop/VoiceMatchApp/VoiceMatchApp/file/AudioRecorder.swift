import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    // ★波形表示用のサンプル（40個に増やし、リアルタイムに更新）
    @Published var soundSamples: [Float] = Array(repeating: 0.05, count: 40)
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    override init() {
        super.init()
        fetchRecordingPermission()
    }
    
    func fetchRecordingPermission() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            session.requestRecordPermission { allowed in
                if !allowed {
                    print("マイクの使用が許可されていません")
                }
            }
        } catch {
            print("セッション設定エラー: \(error)")
        }
    }
    
    func startRecording() {
        // VoiceEffectManagerが読み込めるようにLinearPCM(.wav)形式にする
        let fileName = UUID().uuidString + ".wav"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingURL = nil
                self.soundSamples = Array(repeating: 0.05, count: 40)
                
                // ★0.05秒ごとに音量をサンプリングして、波形を滑らかに動かす
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    self.updateStatus()
                }
            }
        } catch {
            print("録音開始エラー: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        let url = audioRecorder?.url
        timer?.invalidate()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingURL = url
        }
    }
    
    private func updateStatus() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()
        self.recordingDuration = recorder.currentTime
        
        // 音量レベルを取得して正規化
        let power = recorder.averagePower(forChannel: 0)
        let normalized = normalizeSoundLevel(level: power)
        
        DispatchQueue.main.async {
            // ★古いサンプルを捨てて新しいサンプルを追加（流れるような演出）
            self.soundSamples.removeFirst()
            self.soundSamples.append(normalized)
        }
    }
    
    private func normalizeSoundLevel(level: Float) -> Float {
        let lowLevel: Float = -60
        let highLevel: Float = -10
        if level < lowLevel { return 0.01 } // 最小限のバーを表示
        if level > highLevel { return 1.0 }
        return (level - lowLevel) / (highLevel - lowLevel)
    }
}
