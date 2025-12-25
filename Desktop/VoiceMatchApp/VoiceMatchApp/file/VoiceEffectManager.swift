import Foundation
import AVFoundation

enum VoiceEffect: String, CaseIterable {
    case normal = "地声"
    case robot = "ロボット"
    case highPitch = "高音"
    case deepVoice = "低音"
    case whisper = "ささやき"
    case anonymize = "モザイク"
    case echo = "エコー"
    
    var icon: String {
        switch self {
        case .normal: return "person.fill"
        case .robot: return "ant.fill"
        case .highPitch: return "bird.fill"
        case .deepVoice: return "tortoise.fill"
        case .whisper: return "wind"
        case .anonymize: return "questionmark.diamond.fill"
        case .echo: return "waveform"
        }
    }
}

class VoiceEffectManager {
    static let shared = VoiceEffectManager()
    
    func generateProcessedAudio(inputURL: URL, effect: VoiceEffect) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.processAudioSync(inputURL: inputURL, effect: effect)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // 同期的な処理メソッド
    private func processAudioSync(inputURL: URL, effect: VoiceEffect) throws -> URL {
        let audioEngine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let pitchNode = AVAudioUnitTimePitch()
        let reverbNode = AVAudioUnitReverb()
        
        let inputFile = try AVAudioFile(forReading: inputURL)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("processed_\(UUID().uuidString).m4a")
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
        
        audioEngine.attach(playerNode)
        audioEngine.attach(pitchNode)
        audioEngine.attach(reverbNode)
        
        configureNodes(pitchNode: pitchNode, reverbNode: reverbNode, for: effect)
        
        let format = inputFile.processingFormat
        audioEngine.connect(playerNode, to: pitchNode, format: format)
        audioEngine.connect(pitchNode, to: reverbNode, format: format)
        audioEngine.connect(reverbNode, to: audioEngine.mainMixerNode, format: format)
        
        let maxFrames: AVAudioFrameCount = 4096
        try audioEngine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        
        try audioEngine.start()
        playerNode.scheduleFile(inputFile, at: nil)
        playerNode.play()
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.manualRenderingFormat, frameCapacity: maxFrames) else {
            throw NSError(domain: "VoiceEffectManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "バッファの作成に失敗しました"])
        }
        
        // 同期的なレンダリングループ
        var isRendering = true
        while isRendering && audioEngine.manualRenderingSampleTime < inputFile.length {
            let frameCount = inputFile.length - audioEngine.manualRenderingSampleTime
            let framesToRender = min(AVAudioFrameCount(frameCount), maxFrames)
            
            var status: AVAudioEngineManualRenderingStatus = .error
            
            do {
                status = try audioEngine.renderOffline(framesToRender, to: buffer)
            } catch {
                isRendering = false
                break
            }
            
            if status == .success {
                buffer.frameLength = framesToRender
                try outputFile.write(from: buffer)
            } else if status == .error {
                isRendering = false
            }
        }
        
        playerNode.stop()
        audioEngine.stop()
        audioEngine.disableManualRenderingMode()
        
        return outputURL
    }
    
    private func configureNodes(pitchNode: AVAudioUnitTimePitch, reverbNode: AVAudioUnitReverb, for effect: VoiceEffect) {
        pitchNode.pitch = 0
        pitchNode.rate = 1.0
        reverbNode.loadFactoryPreset(.smallRoom)
        reverbNode.wetDryMix = 0
        
        switch effect {
        case .normal: break
        case .robot:
            pitchNode.pitch = -1200; pitchNode.rate = 0.8
        case .highPitch:
            pitchNode.pitch = 1000
        case .deepVoice:
            pitchNode.pitch = -800
        case .whisper:
            pitchNode.rate = 1.1; reverbNode.loadFactoryPreset(.mediumHall); reverbNode.wetDryMix = 30
        case .anonymize:
            pitchNode.pitch = -2400; pitchNode.rate = 0.7
        case .echo:
            reverbNode.loadFactoryPreset(.cathedral); reverbNode.wetDryMix = 45
        }
    }
}
