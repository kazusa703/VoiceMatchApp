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
    
    // エフェクトパラメータ
    let pitch: Float          // -2400 ~ 2400 (cents) - 100 = 半音
    let rate: Float           // 0.5 ~ 2.0
    let reverbPreset: AVAudioUnitReverbPreset?
    let reverbMix: Float      // 0 ~ 100
    let distortionPreset: AVAudioUnitDistortionPreset?
    let distortionMix: Float  // 0 ~ 100
}

struct VoiceEffectConstants {
    // ========================================
    // 無料ユーザー用エフェクト（4種類）
    // ========================================
    static let freeEffects: [VoiceEffectDefinition] = [
        // 1. ノーマル - エフェクトなし
        VoiceEffectDefinition(
            key: "normal",
            displayName: "ノーマル",
            icon: "waveform",
            isProOnly: false,
            pitch: 0,
            rate: 1.0,
            reverbPreset: nil,
            reverbMix: 0,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 2. 高い声 - 5半音上げ
        VoiceEffectDefinition(
            key: "high",
            displayName: "高い声",
            icon: "arrow.up",
            isProOnly: false,
            pitch: 500,
            rate: 1.0,
            reverbPreset: nil,
            reverbMix: 0,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 3. 低い声 - 5半音下げ
        VoiceEffectDefinition(
            key: "low",
            displayName: "低い声",
            icon: "arrow.down",
            isProOnly: false,
            pitch: -500,
            rate: 1.0,
            reverbPreset: nil,
            reverbMix: 0,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 4. エコー - ホールリバーブ
        VoiceEffectDefinition(
            key: "echo",
            displayName: "エコー",
            icon: "dot.radiowaves.left.and.right",
            isProOnly: false,
            pitch: 0,
            rate: 1.0,
            reverbPreset: .mediumHall,
            reverbMix: 50,
            distortionPreset: nil,
            distortionMix: 0
        )
    ]
    
    // ========================================
    // Proユーザー追加エフェクト（+6種類 = 合計10種類）
    // ========================================
    static let proEffects: [VoiceEffectDefinition] = [
        // 5. ロボット - 機械的な声
        VoiceEffectDefinition(
            key: "robot",
            displayName: "ロボット",
            icon: "cpu",
            isProOnly: true,
            pitch: -200,
            rate: 0.95,
            reverbPreset: .smallRoom,
            reverbMix: 25,
            distortionPreset: .speechRadioTower,
            distortionMix: 35
        ),
        // 6. チップマンク - 高くてかわいい声
        VoiceEffectDefinition(
            key: "chipmunk",
            displayName: "チップマンク",
            icon: "hare",
            isProOnly: true,
            pitch: 1000,
            rate: 1.15,
            reverbPreset: nil,
            reverbMix: 0,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 7. 巨人 - 低くて重い声
        VoiceEffectDefinition(
            key: "giant",
            displayName: "巨人",
            icon: "figure.stand",
            isProOnly: true,
            pitch: -800,
            rate: 0.85,
            reverbPreset: .cathedral,
            reverbMix: 35,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 8. ささやき - 囁くような声
        VoiceEffectDefinition(
            key: "whisper",
            displayName: "ささやき",
            icon: "mouth",
            isProOnly: true,
            pitch: 150,
            rate: 0.92,
            reverbPreset: .largeChamber,
            reverbMix: 55,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 9. スタジアム - 大きな空間にいるような声
        VoiceEffectDefinition(
            key: "stadium",
            displayName: "スタジアム",
            icon: "building.columns",
            isProOnly: true,
            pitch: 0,
            rate: 1.0,
            reverbPreset: .largeHall2,
            reverbMix: 70,
            distortionPreset: nil,
            distortionMix: 0
        ),
        // 10. 電話 - 電話越しのような声
        VoiceEffectDefinition(
            key: "telephone",
            displayName: "電話",
            icon: "phone",
            isProOnly: true,
            pitch: 150,
            rate: 1.0,
            reverbPreset: nil,
            reverbMix: 0,
            distortionPreset: .speechCosmicInterference,
            distortionMix: 30
        )
    ]
    
    static var allEffects: [VoiceEffectDefinition] {
        return freeEffects + proEffects
    }
    
    static func getEffectsForUser(isPro: Bool) -> [VoiceEffectDefinition] {
        return isPro ? allEffects : freeEffects
    }
    
    static func getEffect(by key: String) -> VoiceEffectDefinition? {
        return allEffects.first { $0.key == key }
    }
}

// MARK: - エフェクト設定（カスタム調整用）
struct VoiceEffectSettings: Codable {
    var effectKey: String
    var pitch: Float
    var rate: Float
    var reverb: Float      // リバーブ（0〜100）
    var distortion: Float  // ディストーション（0〜100）
    
    init(from definition: VoiceEffectDefinition) {
        self.effectKey = definition.key
        self.pitch = definition.pitch
        self.rate = definition.rate
        self.reverb = definition.reverbMix
        self.distortion = definition.distortionMix
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
    
    @Published var currentEffect: VoiceEffectDefinition
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0
    
    // カスタム調整値（Proユーザー用）
    @Published var customPitch: Float = 0
    @Published var customRate: Float = 1.0
    @Published var customReverbMix: Float = 0
    @Published var customDistortionMix: Float = 0
    
    // 旧API互換性のため（現在のカスタム値を反映）
    var currentSettings: VoiceEffectSettings {
        return VoiceEffectSettings(
            effectKey: currentEffect.key,
            pitch: customPitch,
            rate: customRate,
            reverb: customReverbMix,
            distortion: customDistortionMix
        )
    }
    
    init() {
        self.currentEffect = VoiceEffectConstants.freeEffects[0]
    }
    
    // エフェクトを選択
    func selectEffect(_ definition: VoiceEffectDefinition) {
        currentEffect = definition
        customPitch = definition.pitch
        customRate = definition.rate
        customReverbMix = definition.reverbMix
        customDistortionMix = definition.distortionMix
        print("🎵 [VoiceEffectManager] エフェクト選択: \(definition.displayName)")
    }
    
    // カスタム調整（Proユーザー用）
    func updatePitch(_ value: Float) {
        customPitch = max(-2400, min(2400, value))
    }
    
    func updateRate(_ value: Float) {
        customRate = max(0.5, min(2.0, value))
    }
    
    func updateReverb(_ value: Float) {
        customReverbMix = max(0, min(100, value))
    }
    
    func updateDistortion(_ value: Float) {
        customDistortionMix = max(0, min(100, value))
    }
    
    // MARK: - エフェクト適用（メイン処理）
    
    func applyEffect(to inputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        print("🎵 ========== エフェクト処理開始 ==========")
        print("🎵 エフェクト: \(currentEffect.displayName)")
        print("🎵 入力ファイル: \(inputURL.path)")
        print("🎵 パラメータ: pitch=\(customPitch), rate=\(customRate), reverb=\(customReverbMix), distortion=\(customDistortionMix)")
        
        // ノーマルの場合はそのまま返す
        if currentEffect.key == "normal" &&
           customPitch == 0 &&
           customRate == 1.0 &&
           customReverbMix == 0 &&
           customDistortionMix == 0 {
            print("🎵 ノーマルエフェクト - 元ファイルをそのまま返す")
            completion(.success(inputURL))
            return
        }
        
        // ファイル存在確認
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            print("❌ 入力ファイルが存在しません")
            completion(.failure(VoiceEffectError.fileNotFound))
            return
        }
        
        // ファイルサイズ確認
        if let attrs = try? FileManager.default.attributesOfItem(atPath: inputURL.path),
           let size = attrs[.size] as? Int64 {
            print("🎵 入力ファイルサイズ: \(size) bytes")
            if size == 0 {
                print("❌ ファイルサイズが0です")
                completion(.failure(VoiceEffectError.emptyFile))
                return
            }
        }
        
        isProcessing = true
        processingProgress = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let outputURL = try self.processWithAVAudioEngine(inputURL: inputURL)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processingProgress = 1.0
                    print("✅ エフェクト処理完了: \(outputURL.path)")
                    completion(.success(outputURL))
                }
            } catch {
                print("❌ エフェクト処理エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.processingProgress = 0
                    // エラー時は元ファイルを返す（フォールバック）
                    completion(.success(inputURL))
                }
            }
        }
    }
    
    // MARK: - AVAudioEngine処理
    
    private func processWithAVAudioEngine(inputURL: URL) throws -> URL {
        print("🎵 [AVAudioEngine] 処理開始...")
        
        // 入力ファイルを読み込み
        let inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: inputURL)
        } catch {
            print("❌ [AVAudioEngine] 入力ファイル読み込みエラー: \(error)")
            throw VoiceEffectError.fileNotFound
        }
        
        let format = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)
        
        print("🎵 [AVAudioEngine] サンプルレート: \(format.sampleRate)")
        print("🎵 [AVAudioEngine] チャンネル数: \(format.channelCount)")
        print("🎵 [AVAudioEngine] フレーム数: \(frameCount)")
        
        guard frameCount > 0 else {
            throw VoiceEffectError.emptyFile
        }
        
        // 出力URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        // オーディオエンジンとノードを作成
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let timePitchNode = AVAudioUnitTimePitch()
        let reverbNode = AVAudioUnitReverb()
        let distortionNode = AVAudioUnitDistortion()
        
        // エフェクトパラメータを設定
        timePitchNode.pitch = customPitch
        timePitchNode.rate = customRate
        print("🎵 [AVAudioEngine] TimePitch設定: pitch=\(customPitch), rate=\(customRate)")
        
        // リバーブ設定
        if let reverbPreset = currentEffect.reverbPreset, customReverbMix > 0 {
            reverbNode.loadFactoryPreset(reverbPreset)
            reverbNode.wetDryMix = customReverbMix
            print("🎵 [AVAudioEngine] Reverb設定: preset=\(reverbPreset.rawValue), mix=\(customReverbMix)")
        } else {
            reverbNode.wetDryMix = 0
        }
        
        // ディストーション設定
        if let distortionPreset = currentEffect.distortionPreset, customDistortionMix > 0 {
            distortionNode.loadFactoryPreset(distortionPreset)
            distortionNode.wetDryMix = customDistortionMix
            print("🎵 [AVAudioEngine] Distortion設定: preset=\(distortionPreset.rawValue), mix=\(customDistortionMix)")
        } else {
            distortionNode.wetDryMix = 0
        }
        
        // ノードをエンジンに追加
        engine.attach(playerNode)
        engine.attach(timePitchNode)
        engine.attach(reverbNode)
        engine.attach(distortionNode)
        
        // ノードを接続（チェーン）
        engine.connect(playerNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: distortionNode, format: format)
        engine.connect(distortionNode, to: engine.mainMixerNode, format: format)
        
        // 入力バッファを作成して読み込み
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VoiceEffectError.bufferCreationFailed
        }
        
        do {
            try inputFile.read(into: inputBuffer)
        } catch {
            print("❌ [AVAudioEngine] バッファ読み込みエラー: \(error)")
            throw error
        }
        
        print("🎵 [AVAudioEngine] 入力バッファ読み込み完了: \(inputBuffer.frameLength) frames")
        
        // オフラインレンダリングモードを有効化
        let maxFrames: AVAudioFrameCount = 4096
        
        do {
            try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        } catch {
            print("❌ [AVAudioEngine] オフラインレンダリング設定エラー: \(error)")
            throw error
        }
        
        // エンジンを開始
        do {
            try engine.start()
        } catch {
            print("❌ [AVAudioEngine] エンジン開始エラー: \(error)")
            throw error
        }
        
        // プレイヤーにバッファをスケジュールして再生
        playerNode.scheduleBuffer(inputBuffer, completionHandler: nil)
        playerNode.play()
        
        // 出力バッファを作成（rate変更を考慮して十分なサイズを確保）
        let estimatedOutputFrames = AVAudioFrameCount(Double(frameCount) / Double(customRate)) + 10000
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: estimatedOutputFrames) else {
            throw VoiceEffectError.bufferCreationFailed
        }
        
        // レンダリングループ
        var outputFramePosition: AVAudioFramePosition = 0
        let targetFrames = AVAudioFramePosition(Double(frameCount) / Double(customRate))
        
        print("🎵 [AVAudioEngine] レンダリング開始 (目標: \(targetFrames) frames)")
        
        while engine.manualRenderingSampleTime < targetFrames {
            let framesToRender = min(maxFrames, outputBuffer.frameCapacity - AVAudioFrameCount(outputFramePosition))
            
            guard framesToRender > 0 else { break }
            
            guard let tempBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRender) else {
                break
            }
            
            do {
                let status = try engine.renderOffline(framesToRender, to: tempBuffer)
                
                switch status {
                case .success:
                    // tempBufferの内容をoutputBufferにコピー
                    appendBuffer(from: tempBuffer, to: outputBuffer, at: AVAudioFrameCount(outputFramePosition), channelCount: Int(format.channelCount))
                    outputFramePosition += AVAudioFramePosition(tempBuffer.frameLength)
                    
                    // 進捗更新
                    let progress = Float(outputFramePosition) / Float(targetFrames)
                    DispatchQueue.main.async { [weak self] in
                        self?.processingProgress = min(progress, 0.99)
                    }
                    
                case .insufficientDataFromInputNode:
                    // データ不足 - 処理終了
                    break
                    
                case .cannotDoInCurrentContext:
                    // 現在のコンテキストでは処理不可
                    break
                    
                case .error:
                    throw VoiceEffectError.renderingFailed
                    
                @unknown default:
                    break
                }
            } catch {
                print("❌ [AVAudioEngine] レンダリングエラー: \(error)")
                break
            }
        }
        
        // 最終フレーム長を設定
        outputBuffer.frameLength = AVAudioFrameCount(outputFramePosition)
        
        print("🎵 [AVAudioEngine] レンダリング完了: \(outputBuffer.frameLength) frames")
        
        // クリーンアップ
        playerNode.stop()
        engine.stop()
        
        // 出力ファイルに書き込み
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(
                forWriting: outputURL,
                settings: outputSettings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
        } catch {
            print("❌ [AVAudioEngine] 出力ファイル作成エラー: \(error)")
            throw VoiceEffectError.exportFailed
        }
        
        do {
            try outputFile.write(from: outputBuffer)
        } catch {
            print("❌ [AVAudioEngine] ファイル書き込みエラー: \(error)")
            throw VoiceEffectError.exportFailed
        }
        
        // 出力ファイルサイズ確認
        if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
           let size = attrs[.size] as? Int64 {
            print("✅ [AVAudioEngine] 出力ファイルサイズ: \(size) bytes")
        }
        
        print("🎵 ========== エフェクト処理完了 ==========")
        
        return outputURL
    }
    
    // MARK: - バッファコピーヘルパー
    
    private func appendBuffer(from source: AVAudioPCMBuffer, to destination: AVAudioPCMBuffer, at position: AVAudioFrameCount, channelCount: Int) {
        guard let srcData = source.floatChannelData,
              let dstData = destination.floatChannelData else { return }
        
        let framesToCopy = Int(source.frameLength)
        let dstCapacity = Int(destination.frameCapacity)
        
        for channel in 0..<channelCount {
            let src = srcData[channel]
            let dst = dstData[channel]
            
            for frame in 0..<framesToCopy {
                let dstIndex = Int(position) + frame
                if dstIndex < dstCapacity {
                    dst[dstIndex] = src[frame]
                }
            }
        }
    }
}

// MARK: - エラー定義
enum VoiceEffectError: LocalizedError {
    case bufferCreationFailed
    case renderingFailed
    case noAudioTrack
    case compositionFailed
    case exportFailed
    case fileNotFound
    case emptyFile
    
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
        case .fileNotFound:
            return "音声ファイルが見つかりません"
        case .emptyFile:
            return "音声ファイルが空です"
        }
    }
}
