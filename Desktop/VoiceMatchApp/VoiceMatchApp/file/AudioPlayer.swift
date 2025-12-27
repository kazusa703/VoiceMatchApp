import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentlyPlayingURL: String?
    @Published var playbackProgress: Double = 0
    @Published var errorMessage: String?
    
    private var audioPlayer: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    override init() {
        super.init()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Playback
    
    func startPlayback(url: URL) {
        stopPlayback()
        
        // オーディオセッションの設定
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "オーディオセッションの設定に失敗しました"
            print("🔊 セッション設定エラー: \(error)")
            return
        }
        
        // プレイヤーの作成
        playerItem = AVPlayerItem(url: url)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // 再生終了の通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        // 進捗の監視
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = self.playerItem?.duration,
                  duration.isNumeric else { return }
            
            let currentTime = time.seconds
            let totalTime = duration.seconds
            self.playbackProgress = currentTime / totalTime
        }
        
        audioPlayer?.play()
        isPlaying = true
        currentlyPlayingURL = url.absoluteString
        errorMessage = nil
        
        print("🔊 再生開始: \(url)")
    }
    
    func stopPlayback() {
        audioPlayer?.pause()
        
        if let observer = timeObserver {
            audioPlayer?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        audioPlayer = nil
        playerItem = nil
        isPlaying = false
        currentlyPlayingURL = nil
        playbackProgress = 0
        
        print("🔊 再生停止")
    }
    
    func togglePlayback(url: URL) {
        if isPlaying && currentlyPlayingURL == url.absoluteString {
            stopPlayback()
        } else {
            startPlayback(url: url)
        }
    }
    
    // MARK: - Notifications
    
    @objc private func playerDidFinishPlaying() {
        DispatchQueue.main.async { [weak self] in
            self?.stopPlayback()
            print("🔊 再生完了")
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        stopPlayback()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("🔊 セッション非アクティブ化エラー: \(error)")
        }
    }
}
