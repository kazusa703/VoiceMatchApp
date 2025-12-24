import SwiftUI

extension Color {
    // Instagram風ブランドカラー
    static let brandPurple = Color(red: 131/255, green: 58/255, blue: 180/255)
    static let brandOrange = Color(red: 253/255, green: 29/255, blue: 29/255)
    static let brandYellow = Color(red: 252/255, green: 176/255, blue: 69/255)
    
    // ダークモード対応カラー
    static let adaptiveBackground = Color(UIColor.systemBackground)
    static let adaptiveLabel = Color(UIColor.label)
    static let bubbleGray = Color(UIColor.systemGray5)
}

extension LinearGradient {
    static var instaGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.brandPurple, .brandOrange]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var instaButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.brandOrange, .brandYellow]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
