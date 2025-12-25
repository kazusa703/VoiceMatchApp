import SwiftUI

struct MatchAnimationView: View {
    let partnerName: String
    @Binding var isPresented: Bool
    @EnvironmentObject var messageService: MessageService
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("It's a Match!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .brandPurple, radius: 10)
                
                Text("\(partnerName)さんとマッチしました！")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                HStack(spacing: -20) {
                    Circle().fill(Color.gray).frame(width: 100, height: 100)
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    Circle().fill(Color.brandPurple).frame(width: 100, height: 100)
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                }
                .shadow(radius: 10)
                
                Spacer().frame(height: 50)
                
                Button(action: {
                    messageService.selectedSection = .matches
                    withAnimation { isPresented = false }
                }) {
                    Text("チャットを始める")
                        .font(.headline).foregroundColor(.white)
                        .padding().frame(width: 250)
                        .background(LinearGradient.instaGradient).cornerRadius(30)
                }
                
                Button("あとで") {
                    withAnimation { isPresented = false }
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .scaleEffect(scale).opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0; opacity = 1.0
            }
        }
    }
}
