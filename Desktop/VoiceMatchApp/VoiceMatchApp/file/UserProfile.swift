import Foundation
import FirebaseFirestore
import CoreLocation // ★追加: CLLocationを使用するために必要

struct UserProfile: Identifiable, Codable {
    var uid: String
    var username: String
    var profileImageURL: String?
    var bioAudioURL: String?
    var bio: String = ""
    
    var profileItems: [String: String]
    var privacySettings: [String: Bool] = [:]
    var notificationSettings: [String: Bool] = ["approach": true, "message": true]
    
    var blockedUserIDs: [String] = []
    var skippedUserIDs: [String] = []
    var matchedUserIDs: [String] = []
    
    var matchCountCurrentCycle: Int = 0
    var lastMatchDate: Date? = nil
    var isProUser: Bool = false
    var fcmToken: String? = nil
    var cycleStartTime: Date? = nil
    var maxMatchesPerCycle: Int = 5
    
    // ★追加: 位置情報関連
    var latitude: Double? = nil       // 緯度
    var longitude: Double? = nil      // 経度
    var isLocationPublic: Bool = false // 位置情報の公開設定
    
    // ★追加: CLLocationとして取得するための計算プロパティ
    // (Codableの対象外にするため、保存はされず呼び出し時に生成されます)
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    var id: String { uid }
    
    var reportCount: Int = 0
    var isAccountLocked: Bool = false
    var isAdmin: Bool = false
    
    // 初期化メソッド
    init(uid: String,
         username: String,
         profileImageURL: String? = nil,
         bioAudioURL: String? = nil,
         bio: String = "",
         profileItems: [String: String] = [:],
         privacySettings: [String: Bool] = [:],
         notificationSettings: [String: Bool] = ["approach": true, "message": true],
         blockedUserIDs: [String] = [],
         skippedUserIDs: [String] = [],
         matchedUserIDs: [String] = [],
         matchCountCurrentCycle: Int = 0,
         lastMatchDate: Date? = nil,
         isProUser: Bool = false,
         fcmToken: String? = nil,
         cycleStartTime: Date? = nil,
         maxMatchesPerCycle: Int = 5) {
        
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
