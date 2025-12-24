import SwiftUI
import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // ユーザー設定を確認（UserDefaultsから直接取得）
    var isEnabled: Bool {
        // 設定値がまだない場合（初回起動時）は true(オン) を返す
        if UserDefaults.standard.object(forKey: "isHapticsEnabled") == nil {
            return true
        }
        // 設定がある場合はその値を返す
        return UserDefaults.standard.bool(forKey: "isHapticsEnabled")
    }
    
    // 軽い衝撃（ボタンタップなど）
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare() // 反応速度を上げるために準備
        generator.impactOccurred()
    }
    
    // 通知（成功・失敗など）
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // 選択（ドラムロールなど）
    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
