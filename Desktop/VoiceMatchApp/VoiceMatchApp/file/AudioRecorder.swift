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
            print("🎙️ [AudioRecorder] マイク許可済み")
        case .denied:
            hasPermission = false
            errorMessage = "マイクへのアクセスが拒否されています。設定から許可してください。"
            print("🎙️ [AudioRecorder] マイク拒否")
        case .undetermined:
            print("🎙️ [AudioRecorder] マイク許可未決定 - リクエスト中...")
            requestPermission()
        @unknown default:
            hasPermission = false
        }
    }
    
    func requestPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                print("🎙️ [AudioRecorder] マイク許可結果: \(granted)")
                if !granted {
                    self?.errorMessage = "マイクへのアクセスが許可されていません。"
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        print("🎙️ [AudioRecorder] startRecording呼び出し")
        
        guard hasPermission else {
            errorMessage = "マイクへのアクセスが許可されていません。"
            print("🎙️ [AudioRecorder] エラー: マイク許可なし")
            requestPermission()
            return
        }
        
        // 録音セッションの設定
        let session = AVAudioSession.sharedInstance()
        do {
            // より詳細なオプションを設定
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎙️ [AudioRecorder] オーディオセッション設定成功")
            print("🎙️ [AudioRecorder] 入力チャンネル数: \(session.inputNumberOfChannels)")
            print("🎙️ [AudioRecorder] サンプルレート: \(session.sampleRate)")
            
            // 入力が利用可能か確認
            if session.availableInputs?.isEmpty ?? true {
                print("⚠️ [AudioRecorder] 警告: 利用可能な入力デバイスがありません（シミュレーター?）")
            } else {
                print("🎙️ [AudioRecorder] 入力デバイス: \(session.availableInputs?.map { $0.portName } ?? [])")
            }
            
        } catch {
            errorMessage = "オーディオセッションの設定に失敗しました: \(error.localizedDescription)"
            print("🎙️ [AudioRecorder] オーディオセッションエラー: \(error)")
            return
        }
        
        // 録音ファイルのパス
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        print("🎙️ [AudioRecorder] 録音ファイルパス: \(audioURL.path)")
        
        // 録音設定
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true  // メータリング有効化
            
            let prepared = audioRecorder?.prepareToRecord() ?? false
            print("🎙️ [AudioRecorder] prepareToRecord: \(prepared)")
            
            let started = audioRecorder?.record() ?? false
            print("🎙️ [AudioRecorder] record開始: \(started)")
            
            if started {
                recordingURL = audioURL
                isRecording = true
                errorMessage = nil
                print("✅ [AudioRecorder] 録音開始成功")
                
                // 録音レベルを定期的にログ出力（デバッグ用）
                #if DEBUG
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.logRecordingLevel()
                }
                #endif
            } else {
                errorMessage = "録音の開始に失敗しました"
                print("❌ [AudioRecorder] record()がfalseを返しました")
            }
            
        } catch {
            errorMessage = "録音の開始に失敗しました: \(error.localizedDescription)"
            print("❌ [AudioRecorder] AVAudioRecorder作成エラー: \(error)")
        }
    }
    
    #if DEBUG
    private func logRecordingLevel() {
        guard isRecording, let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        print("🎙️ [AudioRecorder] レベル: avg=\(averagePower)dB, peak=\(peakPower)dB")
        
        // 録音中は1秒ごとにログ
        if isRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.logRecordingLevel()
            }
        }
    }
    #endif
    
    func stopRecording() {
        print("🎙️ [AudioRecorder] stopRecording呼び出し")
        
        guard let recorder = audioRecorder else {
            print("⚠️ [AudioRecorder] audioRecorderがnil")
            return
        }
        
        let currentTime = recorder.currentTime
        print("🎙️ [AudioRecorder] 録音時間: \(currentTime)秒")
        
        recorder.stop()
        isRecording = false
        
        // セッションを非アクティブに
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [AudioRecorder] セッション非アクティブ化エラー: \(error)")
        }
        
        // ファイルサイズと有効性を確認
        if let url = recordingURL {
            print("🎙️ [AudioRecorder] 録音停止: \(url.path)")
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                print("🎙️ [AudioRecorder] ファイルサイズ: \(fileSize) bytes")
                
                if fileSize < 1000 {
                    print("⚠️ [AudioRecorder] 警告: ファイルサイズが小さすぎます（音声データがない可能性）")
                    print("⚠️ [AudioRecorder] シミュレーターを使用している場合、実機でテストしてください")
                    errorMessage = "録音データが不正です。実機でテストしてください。"
                }
            }
            
            // ファイルが有効か確認
            do {
                let audioFile = try AVAudioFile(forReading: url)
                print("🎙️ [AudioRecorder] 有効なオーディオファイル: \(audioFile.length) frames")
            } catch {
                print("❌ [AudioRecorder] 無効なオーディオファイル: \(error)")
                errorMessage = "録音ファイルが無効です。"
            }
        }
    }
    
    func resetRecording() {
        print("🎙️ [AudioRecorder] resetRecording呼び出し")
        
        // 録音中なら停止
        if isRecording {
            audioRecorder?.stop()
            isRecording = false
        }
        
        // 既存の録音ファイルを削除
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            print("🎙️ [AudioRecorder] 録音ファイル削除: \(url.path)")
        }
        
        recordingURL = nil
        errorMessage = nil
        audioRecorder = nil
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
        print("🎙️ [AudioRecorder] audioRecorderDidFinishRecording: success=\(flag)")
        
        if !flag {
            errorMessage = "録音が正常に完了しませんでした。"
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            errorMessage = "エンコードエラー: \(error.localizedDescription)"
            print("❌ [AudioRecorder] エンコードエラー: \(error)")
        }
    }
}
