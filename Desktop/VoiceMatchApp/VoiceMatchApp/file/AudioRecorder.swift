import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    @Published var soundSamples: [Float] = [] // 波形表示用
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio Session Error: \(error)")
        }
        
        let fileName = UUID().uuidString + ".m4a"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingURL = nil
            recordingDuration = 0
            soundSamples = []
            
            startMonitoring()
        } catch {
            print("Recording Error: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingURL = audioRecorder?.url
        stopMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            self.recordingDuration = recorder.currentTime
            
            // 波形用データの更新 (-160dB 〜 0dB を 0.0 〜 1.0 に正規化)
            let power = recorder.averagePower(forChannel: 0)
            let normalized = max(0, (power + 50) / 50)
            
            if self.soundSamples.count > 50 {
                self.soundSamples.removeFirst()
            }
            self.soundSamples.append(normalized)
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
