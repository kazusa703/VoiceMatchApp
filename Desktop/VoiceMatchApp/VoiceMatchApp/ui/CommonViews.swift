import SwiftUI

// MARK: - UserAvatarView（アイコン表示）
struct UserAvatarView: View {
    let imageURL: String?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholderImage
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    private var placeholderImage: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .foregroundColor(.gray.opacity(0.5))
    }
}

// MARK: - VoicePlaybackButton
struct VoicePlaybackButton: View {
    let audioURL: String?
    @ObservedObject var audioPlayer: AudioPlayer
    
    private var isPlaying: Bool {
        guard let url = audioURL else { return false }
        return audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == url
    }
    
    var body: some View {
        Button(action: {
            guard let urlString = audioURL, let url = URL(string: urlString) else { return }
            if isPlaying {
                audioPlayer.stopPlayback()
            } else {
                audioPlayer.startPlayback(url: url)
            }
        }) {
            Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                .font(.title)
                .foregroundColor(.brandPurple)
        }
        .disabled(audioURL == nil)
    }
}



// MARK: - LoadingOverlay
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - CommonPointsBadge
struct CommonPointsBadge: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text("共通点 \(count)個")
                    .font(.caption)
            }
            .foregroundColor(.brandPurple)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandPurple.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - ProBadge
struct ProBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("Pro")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - RecordingIndicator
struct RecordingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 12, height: 12)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - GradientButton
struct GradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isDisabled
                ? LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                : LinearGradient.instaGradient
            )
            .cornerRadius(30)
        }
        .disabled(isDisabled)
    }
}

// MARK: - VoicePlaybackRow
struct VoicePlaybackRow: View {
    let audioURL: String
    let duration: Double
    let isFromMe: Bool
    @ObservedObject var audioPlayer: AudioPlayer
    
    private var isPlaying: Bool {
        audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL
    }
    
    var body: some View {
        HStack {
            if isFromMe { Spacer() }
            
            Button(action: {
                if isPlaying {
                    audioPlayer.stopPlayback()
                } else {
                    if let url = URL(string: audioURL) {
                        audioPlayer.startPlayback(url: url)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                    Text(String(format: "%.1f秒", duration))
                        .font(.caption)
                }
                .foregroundColor(isFromMe ? .white : .brandPurple)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isFromMe ? Color.brandPurple : Color.brandPurple.opacity(0.1))
                .cornerRadius(20)
            }
            
            if !isFromMe { Spacer() }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        UserAvatarView(imageURL: nil, size: 80)
        CommonPointsBadge(count: 5)
        ProBadge()
        GradientButton(title: "いいね", icon: "heart.fill") {}
    }
    .padding()
}
