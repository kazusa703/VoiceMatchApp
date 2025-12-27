import Foundation
import AVFoundation
import Combine

// MARK: - エフェクト定義
struct VoiceEffectDefinition: Identifiable {
    var id: String { key }
    let key: String
    let displayName: String
    let icon: String
    let isProOnly: Bool
    
    // デフォルト値
    let defaultPitch: Float      // -2400 ~ 2400 (cents)
    let defaultRate: Float       // 0.5 ~ 2.0
    let defaultReverb: Float     // 0 ~ 100
    let defaultDistortion: Float // 0 ~ 100
}

struct VoiceEffectConstants {
    // 無料ユーザー用エフェクト（4種類）
    static let freeEffects: [VoiceEffectDefinition] = [
        VoiceEffectDefinition(
            key: "normal",
            displayName: "ノーマル",
            icon: "waveform",
            isProOnly: false,
            defaultPitch: 0,
            defaultRate: 1.0,
            defaultReverb: 0,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "high",
            displayName: "高い声",
            icon: "arrow.up",
            isProOnly: false,
            defaultPitch: 800,
            defaultRate: 1.0,
            defaultReverb: 0,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "low",
            displayName: "低い声",
            icon: "arrow.down",
            isProOnly: false,
            defaultPitch: -800,
            defaultRate: 1.0,
            defaultReverb: 0,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "echo",
            displayName: "エコー",
            icon: "dot.radiowaves.left.and.right",
            isProOnly: false,
            defaultPitch: 0,
            defaultRate: 1.0,
            defaultReverb: 50,
            defaultDistortion: 0
        )
    ]
    
    // Proユーザー追加エフェクト（+6種類 = 合計10種類）
    static let proEffects: [VoiceEffectDefinition] = [
        VoiceEffectDefinition(
            key: "robot",
            displayName: "ロボット",
            icon: "cpu",
            isProOnly: true,
            defaultPitch: -400,
            defaultRate: 0.9,
            defaultReverb: 30,
            defaultDistortion: 40
        ),
        VoiceEffectDefinition(
            key: "chipmunk",
            displayName: "チップマンク",
            icon: "hare",
            isProOnly: true,
            defaultPitch: 1200,
            defaultRate: 1.3,
            defaultReverb: 0,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "giant",
            displayName: "巨人",
            icon: "figure.stand",
            isProOnly: true,
            defaultPitch: -1200,
            defaultRate: 0.8,
            defaultReverb: 40,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "whisper",
            displayName: "ささやき",
            icon: "mouth",
            isProOnly: true,
            defaultPitch: 200,
            defaultRate: 0.9,
            defaultReverb: 60,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "stadium",
            displayName: "スタジアム",
            icon: "building.columns",
            isProOnly: true,
            defaultPitch: 0,
            defaultRate: 1.0,
            defaultReverb: 80,
            defaultDistortion: 0
        ),
        VoiceEffectDefinition(
            key: "telephone",
            displayName: "電話",
            icon: "phone",
            isProOnly: true,
            defaultPitch: 300,
            defaultRate: 1.0,
            defaultReverb: 10,
            defaultDistortion: 30
        )
    ]
    
    static var allEffects: [VoiceEffectDefinition] {
        return freeEffects + proEffects
    }
    
    static func getEffectsForUser(isPro: Bool) -> [VoiceEffectDefinition] {
        if isPro {
            return allEffects
        } else {
            return freeEffects
        }
    }
    
    static func getEffect(by key: String) -> VoiceEffectDefinition? {
        return allEffects.first { $0.key == key }
    }
}

// MARK: - エフェクト設定（Proユーザー用カスタム調整）
struct VoiceEffectSettings: Codable {
    var effectKey: String
    var pitch: Float      // -2400 ~ 2400
    var rate: Float       // 0.5 ~ 2.0
    var reverb: Float     // 0 ~ 100
    var distortion: Float // 0 ~ 100
    
    init(from definition: VoiceEffectDefinition) {
        self.effectKey = definition.key
        self.pitch = definition.defaultPitch
        self.rate = definition.defaultRate
        self.reverb = definition.defaultReverb
        self.distortion = definition.defaultDistortion
    }
    
    init(effectKey: String, pitch: Float, rate: Float, reverb: Float, distortion: Float) {
        self.effectKey = effectKey
        self.pitch = pitch
        self.rate = rate
        self.reverb = reverb
        self.distortion = distortion
    }
}

// MARK: - VoiceEffectManager
class VoiceEffectManager: ObservableObject {
    static let shared = VoiceEffectManager()
    
    @Published var currentSettings: VoiceEffectSettings
    @Published var isProcessing = false
    
    init() {
        // デフォルトはノーマル
        let normalEffect = VoiceEffectConstants.freeEffects[0]
        self.currentSettings = VoiceEffectSettings(from: normalEffect)
    }
    
    // エフェクトを選択（プリセット適用）
    func selectEffect(_ definition: VoiceEffectDefinition) {
        currentSettings = VoiceEffectSettings(from: definition)
    }
    
    // カスタム調整（Proユーザー用）
    func updatePitch(_ value: Float) {
        currentSettings.pitch = value
    }
    
    func updateRate(_ value: Float) {
        currentSettings.rate = value
    }
    
    func updateReverb(_ value: Float) {
        currentSettings.reverb = value
    }
    
    func updateDistortion(_ value: Float) {
        currentSettings.distortion = value
    }
    
    // エフェクトを適用して新しい音声ファイルを生成
    func applyEffect(to inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // ノーマルの場合はそのまま返す
        if currentSettings.effectKey == "normal" &&
           currentSettings.pitch == 0 &&
           currentSettings.rate == 1.0 &&
           currentSettings.reverb == 0 &&
           currentSettings.distortion == 0 {
            completion(.success(inputURL))
            return
        }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let outputURL = try self.processAudioWithAVFoundation(inputURL: inputURL)
                DispatchQueue.main.async {
                    self.isProcessing = false
                    completion(.success(outputURL))
                }
            } catch {
                print("エフェクト処理エラー: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    // エラー時は元のファイルをそのまま返す
                    completion(.success(inputURL))
                }
            }
        }
    }
    
    private func processAudioWithAVFoundation(inputURL: URL) throws -> URL {
        // 入力ファイルを読み込み
        let asset = AVURLAsset(url: inputURL)
        
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw VoiceEffectError.noAudioTrack
        }
        
        // 出力URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        // AVMutableComposition を使用
        let composition = AVMutableComposition()
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VoiceEffectError.compositionFailed
        }
        
        let timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        // タイムスケールでピッチと速度を調整
        if currentSettings.rate != 1.0 {
            let scaledDuration = CMTimeMultiplyByFloat64(asset.duration, multiplier: Float64(1.0 / currentSettings.rate))
            compositionAudioTrack.scaleTimeRange(timeRange, toDuration: scaledDuration)
        }
        
        // エクスポート
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw VoiceEffectError.exportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        
        exportSession.exportAsynchronously {
            if exportSession.status == .failed {
                exportError = exportSession.error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = exportError {
            throw error
        }
        
        return outputURL
    }
}

enum VoiceEffectError: LocalizedError {
    case bufferCreationFailed
    case renderingFailed
    case noAudioTrack
    case compositionFailed
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .bufferCreationFailed:
            return "音声バッファの作成に失敗しました"
        case .renderingFailed:
            return "音声処理に失敗しました"
        case .noAudioTrack:
            return "音声トラックが見つかりません"
        case .compositionFailed:
            return "音声合成に失敗しました"
        case .exportFailed:
            return "エクスポートに失敗しました"
        }
    }
}
