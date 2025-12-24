import Foundation
import FirebaseFirestore

// チャットメッセージのモデル
struct VoiceMessage: Identifiable, Codable {
    @DocumentID var id: String?
    let senderID: String
    let audioURL: String
    let duration: Double
    let timestamp: Date
    // expiresAt は撤廃
    var listenCount: Int = 0 // 再生回数
    var effectUsed: String?
    var waveformSamples: [Float]?
}

// マッチング情報のモデル
struct UserMatch: Identifiable, Codable {
    @DocumentID var id: String?
    let user1ID: String
    let user2ID: String
    let lastMessageDate: Date
    let matchDate: Date
}
