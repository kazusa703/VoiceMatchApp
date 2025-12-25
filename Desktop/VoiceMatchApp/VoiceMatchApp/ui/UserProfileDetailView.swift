import SwiftUI

struct UserProfileDetailView: View {
    let user: UserProfile
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                UserAvatarView(imageURL: user.profileImageURL, size: 150)
                    .padding(.top)
                
                Text(user.username)
                    .font(.title)
                    .fontWeight(.bold)
                
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                // 自己紹介ボイス - bioAudioURLがnilでないか確認
                if let audioURLString = user.bioAudioURL,
                   !audioURLString.isEmpty,
                   let url = URL(string: audioURLString) {
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.stopPlayback()
                        } else {
                            audioPlayer.startPlayback(url: url)
                        }
                    }) {
                        HStack {
                            Image(systemName: audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                            Text("自己紹介ボイスを再生")
                        }
                        .padding()
                        .background(Color.brandPurple.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                
                Divider()
                
                // プロフィール詳細
                VStack(alignment: .leading, spacing: 15) {
                    Text("詳細データ")
                        .font(.headline)
                    
                    ForEach(ProfileConstants.items, id: \.key) { item in
                        let isPublic = user.privacySettings[item.key] ?? true
                        if isPublic,
                           let value = user.profileItems[item.key],
                           !value.isEmpty {
                            HStack {
                                Text(item.displayName)
                                    .foregroundColor(.secondary)
                                    .frame(width: 100, alignment: .leading)
                                Text(value)
                                    .fontWeight(.medium)
                            }
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .padding()
                
                Spacer()
            }
        }
        .navigationTitle(user.username)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
