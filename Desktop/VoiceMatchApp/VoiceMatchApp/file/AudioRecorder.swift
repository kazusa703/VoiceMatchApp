import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var hasPermission = false
    @Published var errorMessage: String?
    
    private var audioRecorder: AVAudioRecorder?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    // MARK: - Permission
    
    func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasPermission = true
        case .denied:
            hasPermission = false
            errorMessage = "マイクへのアクセスが拒否されています。設定から許可してください。"
        case .undetermined:
            requestPermission()
        @unknown default:
            hasPermission = false
        }
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if !granted {
                    self?.errorMessage = "マイクへのアクセスが許可されていません。"
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard hasPermission else {
            errorMessage = "マイクへのアクセスが許可されていません。"
            requestPermission()
            return
        }
        
        // 録音セッションの設定
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            errorMessage = "オーディオセッションの設定に失敗しました: \(error.localizedDescription)"
            return
        }
        
        // 録音ファイルのパス
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        // 録音設定
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            recordingURL = audioURL
            isRecording = true
            errorMessage = nil
            
            print("🎙️ 録音開始: \(audioURL.path)")
        } catch {
            errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
            print("🎙️ 録音開始エラー: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // セッションを非アクティブに
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("🎙️ セッション非アクティブ化エラー: \(error)")
        }
        
        if let url = recordingURL {
            print("🎙️ 録音停止: \(url.path)")
            
            // ファイルサイズを確認
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                print("🎙️ ファイルサイズ: \(fileSize) bytes")
            }
        }
    }
    
    func resetRecording() {
        // 既存の録音ファイルを削除
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            print("🎙️ 録音ファイル削除: \(url.path)")
        }
        
        recordingURL = nil
        isRecording = false
        errorMessage = nil
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopRecording()
        resetRecording()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "録音が正常に完了しませんでした。"
            print("🎙️ 録音失敗")
        } else {
            print("🎙️ 録音完了")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            errorMessage = "エンコードエラー: \(error.localizedDescription)"
            print("🎙️ エンコードエラー: \(error)")
        }
    }
}
