import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentlyPlayingURL: String?
    
    private var audioPlayer: AVAudioPlayer?
    
    // キャッシュを保存するディレクトリの取得
    private let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    
    // クリーンアップの閾値設定
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 3 * 24 * 60 * 60 // 3日間

    override init() {
        super.init()
        // アプリ起動時に古いキャッシュを自動掃除する
        Task {
            self.autoCleanupCache()
        }
    }
    
    func startPlayback(url: URL) {
        if isPlaying {
            stopPlayback()
        }
        
        // A. ローカルファイルの場合 (録音直後など)
        if url.isFileURL {
            playLocalFile(url: url)
            return
        }
        
        // B. リモートURLの場合 (キャッシュを確認)
        let safeFileName = url.lastPathComponent.replacingOccurrences(of: "/", with: "_")
        let cachedFileURL = cacheDirectory.appendingPathComponent(safeFileName)
        
        // キャッシュが存在するか確認
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            print("DEBUG: キャッシュから再生します: \(cachedFileURL.lastPathComponent)")
            playLocalFile(url: cachedFileURL)
            return
        }
        
        // キャッシュがない場合はダウンロードして保存・再生
        downloadAndPlay(from: url, saveTo: cachedFileURL)
    }
    
    // ダウンロードと保存
    private func downloadAndPlay(from url: URL, saveTo destination: URL) {
        Task {
            await MainActor.run { self.isLoading = true }
            
            do {
                print("DEBUG: 新規ダウンロード開始: \(url.lastPathComponent)")
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard httpResponse.statusCode == 200 else {
                        print("❌ サーバーエラー (Status: \(httpResponse.statusCode)): ファイルが見つかりません")
                        await MainActor.run {
                            self.isLoading = false
                            self.stopPlayback()
                        }
                        return
                    }
                }
                
                // データをキャッシュに保存
                try data.write(to: destination)
                print("DEBUG: キャッシュに保存完了")
                
                await MainActor.run {
                    self.playData(data: data, url: url)
                    self.isLoading = false
                }
            } catch {
                print("❌ ダウンロードまたは保存エラー: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                    self.stopPlayback()
                }
            }
        }
    }
    
    // ローカル再生用
    private func playLocalFile(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            setupAndPlay(url: url)
        } catch {
            print("ローカル再生エラー: \(error.localizedDescription)")
            stopPlayback()
        }
    }
    
    // データ再生用（初回ダウンロード時）
    private func playData(data: Data, url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            setupAndPlay(url: url)
        } catch {
            print("データ再生エラー: \(error.localizedDescription)")
            stopPlayback()
        }
    }
    
    private func setupAndPlay(url: URL) {
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        
        isPlaying = true
        currentlyPlayingURL = url.absoluteString
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        currentlyPlayingURL = nil
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentlyPlayingURL = nil
    }
    
    // 時間指定シーク（シークバー用）
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
    }
    
    var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
    
    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    // MARK: - キャッシュクリーンアップ機能
    func autoCleanupCache() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        ) else { return }
        
        let now = Date()
        var currentCacheSize: Int64 = 0
        var fileInfos: [(url: URL, date: Date, size: Int64)] = []
        
        for fileURL in files {
            guard ["m4a", "wav", "mp3"].contains(fileURL.pathExtension.lowercased()) else { continue }
            
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path)
            let modificationDate = attributes?[.modificationDate] as? Date ?? Date.distantPast
            let fileSize = attributes?[.size] as? Int64 ?? 0
            
            if now.timeIntervalSince(modificationDate) > maxCacheAge {
                try? fileManager.removeItem(at: fileURL)
                print("DEBUG: 期限切れキャッシュを削除しました: \(fileURL.lastPathComponent)")
                continue
            }
            
            currentCacheSize += fileSize
            fileInfos.append((fileURL, modificationDate, fileSize))
        }
        
        if currentCacheSize > maxCacheSize {
            let sortedFiles = fileInfos.sorted { $0.date < $1.date }
            var sizeToRemove = currentCacheSize - maxCacheSize
            
            for file in sortedFiles {
                if sizeToRemove <= 0 { break }
                try? fileManager.removeItem(at: file.url)
                sizeToRemove -= file.size
                print("DEBUG: 容量制限のため古いキャッシュを削除しました: \(file.url.lastPathComponent)")
            }
        }
    }
}
