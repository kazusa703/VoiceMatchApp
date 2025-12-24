import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<samples.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient.instaGradient)
                    .frame(width: 4, height: CGFloat(samples[index]) * 60 + 5)
                    .animation(.spring(), value: samples[index])
            }
        }
        .frame(height: 80)
    }
}
