import SwiftUI
import AVFoundation

struct UserProfileDetailView: View {
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
                        
                        // ★修正: 年齢が非公開設定なら表示しない
                        if isItemPublic("age"), let age = user.profileItems["age"], !age.isEmpty {
                            Text(age)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 20)
                
                // 2. ボイスプレーヤー (自己紹介ボイス)
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
                        .background(Color.adaptiveBackground)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                }
                
                // 3. 自己紹介文 (Bio)
                // ★修正: bioも非公開設定をチェック可能にする (デフォルトは公開)
                if isItemPublic("bio") && !user.bio.isEmpty {
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
                    .background(Color.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                // 4. 詳細プロフィール (30項目のグリッド表示)
                let publicItems = ProfileConstants.items.filter { item in
                    isItemPublic(item.key) && !(user.profileItems[item.key]?.isEmpty ?? true)
                }
                
                if !publicItems.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("詳細プロフィール")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                            ForEach(publicItems, id: \.key) { item in
                                InfoBadge(
                                    icon: getIcon(for: item.key),
                                    title: item.displayName,
                                    value: user.profileItems[item.key] ?? ""
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 5. 共通点リスト
                let commonPoints = calculateCommonPoints()
                if !commonPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("あなたとの共通点")
                        }
                        .font(.headline)
                        .foregroundColor(.brandPurple)
                        
                        ForEach(commonPoints, id: \.self) { point in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandPurple)
                                Text(point)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.brandPurple.opacity(0.05))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 120)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        // 下部のアプローチボタン
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
    
    // MARK: - Helper Methods
    
    /// 項目が公開されているかチェックする
    private func isItemPublic(_ key: String) -> Bool {
        // 設定がない場合はデフォルトで「公開(true)」とする
        return user.privacySettings[key] ?? true
    }
    
    /// 共通点を計算する (相手が非公開にしている項目は含めない)
    private func calculateCommonPoints() -> [String] {
        guard let myProfile = userService.currentUserProfile else { return [] }
        var points: [String] = []
        
        for item in ProfileConstants.items {
            // 自分の値と相手の値が存在し、一致しているか
            if let myVal = myProfile.profileItems[item.key],
               let userVal = user.profileItems[item.key],
               !myVal.isEmpty, myVal == userVal {
                
                // ★重要: 相手がその項目を非公開にしているなら、共通点としても表示しない
                if isItemPublic(item.key) {
                    points.append("\(item.displayName): \(userVal)")
                }
            }
        }
        return points
    }
    
    /// 項目キーに応じたアイコンを返す (任意)
    private func getIcon(for key: String) -> String {
        switch key {
        case "residence": return "mappin.and.ellipse"
        case "age": return "person"
        case "occupation": return "briefcase"
        case "hobby": return "heart"
        case "alcohol": return "wineglass"
        case "smoking": return "lungs"
        default: return "circle.fill"
        }
    }
}

// MARK: - Subviews

struct InfoBadge: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.brandPurple)
                .font(.caption)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10)).foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.02), radius: 2)
    }
}
