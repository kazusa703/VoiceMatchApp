import SwiftUI
import AVFoundation

struct PartnerProfileDetailView: View {
    let user: UserProfile
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var messageService: MessageService
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. ヘッダー (アイコン・名前・年齢)
                VStack(spacing: 16) {
                    UserAvatarView(imageURL: user.profileImageURL, size: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 60)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    VStack(spacing: 4) {
                        Text(user.username)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // 年齢 (公開設定があればチェック)
                        if user.privacySettings["age"] ?? true {
                            Text(user.profileItems["age"] ?? "年齢未設定")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                
                // 2. ボイスプレーヤー
                if let audioURL = user.bioAudioURL, let url = URL(string: audioURL) {
                    Button(action: {
                        if audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL {
                            audioPlayer.stopPlayback()
                        } else {
                            audioPlayer.startPlayback(url: url)
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: audioPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.brandPurple)
                            
                            VStack(alignment: .leading) {
                                Text("自己紹介ボイス")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(audioPlayer.isPlaying ? "再生中..." : "タップして再生")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                }
                
                // 3. 自己紹介文 (Bio)
                if !user.bio.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("自己紹介")
                            .font(.headline)
                        Text(user.bio)
                            .font(.body)
                            .foregroundColor(.primary.opacity(0.8))
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.adaptiveBackground)
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                // 4. 基本情報 (公開されているものだけ表示)
                VStack(alignment: .leading, spacing: 15) {
                    Text("基本情報")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                        // ★修正: label -> title に変更し、オプショナルを ?? "未設定" で解除
                        
                        if isItemPublic("residence") {
                            InfoRow(icon: "mappin.and.ellipse", title: "居住地", value: user.profileItems["residence"] ?? "未設定")
                        }
                        
                        if isItemPublic("occupation") {
                            InfoRow(icon: "briefcase", title: "職業", value: user.profileItems["occupation"] ?? "未設定")
                        }
                        
                        if isItemPublic("holiday") {
                            InfoRow(icon: "calendar", title: "休日", value: user.profileItems["holiday"] ?? "未設定")
                        }
                        
                        if isItemPublic("alcohol") {
                            InfoRow(icon: "wineglass", title: "お酒", value: user.profileItems["alcohol"] ?? "未設定")
                        }
                        
                        if isItemPublic("smoking") {
                            InfoRow(icon: "lungs", title: "タバコ", value: user.profileItems["smoking"] ?? "未設定")
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 5. 共通点リスト
                let commonPoints = calculateCommonPoints()
                if !commonPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("あなたとの共通点")
                            .font(.headline)
                            .foregroundColor(.brandPurple)
                        
                        ForEach(commonPoints, id: \.self) { point in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandPurple)
                                Text(point)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.brandPurple.opacity(0.05))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            VStack {
                Spacer()
                NavigationLink(destination: VoiceRecordingView(receiverID: user.uid, mode: .approach)) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("この声にメッセージを送る")
                            .fontWeight(.bold)
                    }
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient.instaGradient)
                    .clipShape(Capsule())
                    .shadow(color: Color.brandPurple.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        )
    }
    
    private func isItemPublic(_ key: String) -> Bool {
        return user.privacySettings[key] ?? true
    }
    
    private func calculateCommonPoints() -> [String] {
        guard let myProfile = userService.currentUserProfile else { return [] }
        var points: [String] = []
        
        let itemLabels = [
            "residence": "居住地", "occupation": "職業", "age": "年齢",
            "holiday": "休日", "alcohol": "お酒", "smoking": "タバコ"
        ]
        
        for (key, label) in itemLabels {
            if let myVal = myProfile.profileItems[key],
               let userVal = user.profileItems[key],
               myVal == userVal {
                
                if isItemPublic(key) {
                    points.append("\(label): \(userVal)")
                }
            }
        }
        return points
    }
}

// サブビュー定義
struct InfoRow: View {
    let icon: String
    let title: String // label ではなく title を使用
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
    }
}
