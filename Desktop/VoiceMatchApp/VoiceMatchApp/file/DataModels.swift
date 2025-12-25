import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - ユーザープロフィール
struct UserProfile: Identifiable, Codable {
    var uid: String
    var username: String
    var profileImageURL: String?
    var bioAudioURL: String?
    var bio: String = ""
    
    // 詳細プロフィール
    var profileItems: [String: String] = [:]
    var privacySettings: [String: Bool] = [:]
    var notificationSettings: [String: Bool] = ["approach": true, "match": true, "message": true]
    
    // リスト管理
    var blockedUserIDs: [String] = []
    var skippedUserIDs: [String] = []
    var matchedUserIDs: [String] = []
    
    // 制限管理
    var matchCountCurrentCycle: Int = 0
    var lastMatchDate: Date? = nil
    var cycleStartTime: Date? = nil
    var maxMatchesPerCycle: Int = 5
    
    // ステータス
    var isProUser: Bool = false
    var isAccountLocked: Bool = false
    var isAdmin: Bool = false
    var reportCount: Int = 0
    
    // 位置情報
    var latitude: Double? = nil
    var longitude: Double? = nil
    var isLocationPublic: Bool = false
    
    var fcmToken: String? = nil
    
    var id: String { uid }
    
    // 計算プロパティ
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    // カスタムイニシャライザ
    init(
        uid: String,
        username: String,
        profileImageURL: String? = nil,
        bioAudioURL: String? = nil,
        bio: String = "",
        profileItems: [String: String] = [:],
        privacySettings: [String: Bool] = [:],
        notificationSettings: [String: Bool] = ["approach": true, "match": true, "message": true],
        blockedUserIDs: [String] = [],
        skippedUserIDs: [String] = [],
        matchedUserIDs: [String] = [],
        matchCountCurrentCycle: Int = 0,
        lastMatchDate: Date? = nil,
        isProUser: Bool = false,
        fcmToken: String? = nil,
        cycleStartTime: Date? = nil,
        maxMatchesPerCycle: Int = 5
    ) {
        self.uid = uid
        self.username = username
        self.profileImageURL = profileImageURL
        self.bioAudioURL = bioAudioURL
        self.bio = bio
        self.profileItems = profileItems
        self.privacySettings = privacySettings
        self.notificationSettings = notificationSettings
        self.blockedUserIDs = blockedUserIDs
        self.skippedUserIDs = skippedUserIDs
        self.matchedUserIDs = matchedUserIDs
        self.matchCountCurrentCycle = matchCountCurrentCycle
        self.lastMatchDate = lastMatchDate
        self.isProUser = isProUser
        self.fcmToken = fcmToken
        self.cycleStartTime = cycleStartTime
        self.maxMatchesPerCycle = maxMatchesPerCycle
    }
}

// MARK: - マッチング情報
struct UserMatch: Identifiable, Codable {
    @DocumentID var id: String?
    let user1ID: String
    let user2ID: String
    var lastMessageDate: Date
    var matchDate: Date
    
    init(id: String? = nil, user1ID: String, user2ID: String, lastMessageDate: Date = Date(), matchDate: Date = Date()) {
        self.id = id
        self.user1ID = user1ID
        self.user2ID = user2ID
        self.lastMessageDate = lastMessageDate
        self.matchDate = matchDate
    }
}

// MARK: - アプローチ/メッセージ
struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let senderID: String
    let receiverID: String
    let audioURL: String
    let duration: Double
    let createdAt: Date
    var isRead: Bool = false
    var isMatched: Bool = false
    
    // 受信箱で表示するための送信者情報
    var senderName: String?
    var senderIconURL: String?
}

// MARK: - ボイスメッセージ詳細（チャット内）
struct VoiceMessage: Identifiable, Codable {
    @DocumentID var id: String?
    let senderID: String
    let audioURL: String
    let duration: Double
    let timestamp: Date
    var listenCount: Int = 0
    var effectUsed: String = "Normal"
    var waveformSamples: [Float]?
}

// MARK: - 録音モード
enum RecordingMode {
    case approach
    case chatReply(matchID: String)
}

// MARK: - 通報データ
struct Report: Identifiable, Codable {
    @DocumentID var id: String?
    let reporterID: String
    let targetID: String
    let reason: String
    let comment: String
    let audioURL: String?
    let timestamp: Date
}
