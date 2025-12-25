import UserNotifications

class NotificationManager {
    static let instance = NotificationManager()
    
    /// ユーザーに通知の許可を求めます
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("通知許可リクエストエラー: \(error.localizedDescription)")
            } else if granted {
                print("通知許可が得られました")
            }
        }
    }
    
    /// 12時間後のサイクルリセット（ボイス送信回数の回復）を通知します
    func scheduleResetNotification() {
        // 既存の待機中通知をキャンセルして重複を防ぎます
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "ボイス送信回数が回復しました！"
        content.body = "新しい声を探しに行きましょう。"
        content.sound = .default
        content.badge = 1
        
        // 12時間後 (43200秒) に発火するようにトリガーを設定
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 12 * 60 * 60, repeats: false)
        
        let request = UNNotificationRequest(identifier: "cycle_reset", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知スケジュールエラー: \(error.localizedDescription)")
            }
        }
    }
}
