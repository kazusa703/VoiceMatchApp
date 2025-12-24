import SwiftUI // これが不足していたためエラーが出ていました

struct MatchAnimationView: View {
    let partnerName: String
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 背景にインスタ風グラデーションを適用（ダークモードでも映えます）
            LinearGradient.instaGradient
                .ignoresSafeArea()
            
            // 装飾用のキラキラした円（背後）
            VStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 400, height: 400)
                        .scaleEffect(1.5)
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 300, height: 300)
                        .offset(x: -100, y: -200)
                }
                Spacer()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // タイトル
                Text("It's a Match!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
                // ユーザーアイコンの重なり演出
                HStack(spacing: -30) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 130, height: 130)
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70)
                            .foregroundColor(.brandPurple)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 130, height: 130)
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70)
                            .foregroundColor(.brandOrange)
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 10) {
                    Text("\(partnerName)さんと")
                    Text("繋がりました！")
                }
                .font(.title2.bold())
                .foregroundColor(.white)
                
                Spacer()
                
                // 閉じるボタン
                Button(action: {
                    isPresented = false
                }) {
                    Text("ボイスを聴きに行く")
                        .font(.headline)
                        .foregroundColor(.brandOrange)
                        .frame(width: 260, height: 60)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// プレビュー用
struct MatchAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        MatchAnimationView(partnerName: "テストユーザー", isPresented: .constant(true))
    }
}
