import UserNotifications

class NotificationManager {
    static let instance = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func scheduleResetNotification() {
        // 既存の通知をキャンセル
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "ボイス送信回数が回復しました！"
        content.body = "新しい声を探しに行きましょう。"
        content.sound = .default
        
        // 12時間後 (43200秒)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 12 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "cycle_reset", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}
