import SwiftUI

struct OnboardingView: View {
    // チュートリアル完了フラグ（完了したら保存される）
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var currentPage = 0
    
    let slides = [
        OnboardingSlide(image: "mic.circle.fill", title: "声でつながる", description: "プロフィール写真や条件だけではなく、\n「声」の雰囲気で相手を探せます。"),
        OnboardingSlide(image: "hourglass", title: "24時間の儚さ", description: "ボイスメッセージは24時間で消滅。\n今この瞬間だけの会話を楽しみましょう。"),
        OnboardingSlide(image: "heart.fill", title: "返信でマッチング", description: "気になった相手に声を送って、\n返信が来たらマッチング成立です。")
    ]
    
    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()
            
            VStack {
                // スキップボタン
                HStack {
                    Spacer()
                    Button("スキップ") {
                        completeOnboarding()
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }
                
                // スライドエリア
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        VStack(spacing: 20) {
                            Image(systemName: slides[index].image)
                                .font(.system(size: 100))
                                .foregroundColor(.brandPurple)
                                .padding(.bottom, 30)
                                .shadow(color: .brandPurple.opacity(0.3), radius: 10)
                            
                            Text(slides[index].title)
                                .font(.title.bold())
                            
                            Text(slides[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 30)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // 進む・始めるボタン
                Button(action: {
                    if currentPage < slides.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < slides.count - 1 ? "次へ" : "はじめる")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient.instaGradient)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                }
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
        // 初回のみ振動でフィードバック
        HapticManager.shared.notification(type: .success)
    }
}

struct OnboardingSlide {
    let image: String
    let title: String
    let description: String
}
