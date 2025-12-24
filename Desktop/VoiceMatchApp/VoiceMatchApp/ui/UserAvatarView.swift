import SwiftUI

struct UserAvatarView: View {
    let imageURL: String?
    let size: CGFloat
    
    var body: some View {
        if let urlString = imageURL, let url = URL(string: urlString) {
            // 画像がある場合
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            // 画像がない場合（デフォルト）
            placeholder
        }
    }
    
    // デフォルトのグラデーションアイコン
    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(LinearGradient.instaGradient)
                .frame(width: size, height: size)
            Image(systemName: "person.fill")
                .foregroundColor(.white)
                .font(.system(size: size * 0.5))
        }
    }
}
