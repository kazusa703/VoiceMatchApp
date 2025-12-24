import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let senderID: String
    let receiverID: String
    let audioURL: String
    let duration: TimeInterval
    let createdAt: Date
    
    // 状態管理
    var isRead: Bool = false
    var isMatched: Bool = false // これがtrueになるとマッチ成立
    
    // 受信箱で表示するための送信者情報
    var senderName: String?
    var senderIconURL: String?
}
