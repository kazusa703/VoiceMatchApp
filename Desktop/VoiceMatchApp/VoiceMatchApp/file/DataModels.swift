import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - ボイスプロフィール項目定義
struct VoiceProfileItem: Identifiable, Codable {
    var id: String { key }
    let key: String
    let displayName: String
    let allowsEffect: Bool
    let isRequired: Bool
    let minDuration: Double
    let maxDuration: Double
}

struct VoiceProfileConstants {
    static let items: [VoiceProfileItem] = [
        VoiceProfileItem(
            key: "naturalVoice",
            displayName: "地声",
            allowsEffect: false,
            isRequired: true,
            minDuration: 1.0,
            maxDuration: 60.0
        ),
        VoiceProfileItem(
            key: "introduction",
            displayName: "自己紹介",
            allowsEffect: true,
            isRequired: false,
            minDuration: 0.0,
            maxDuration: 60.0
        ),
        VoiceProfileItem(
            key: "catchphrase",
            displayName: "口癖",
            allowsEffect: true,
            isRequired: false,
            minDuration: 0.0,
            maxDuration: 60.0
        ),
        VoiceProfileItem(
            key: "greeting",
            displayName: "挨拶",
            allowsEffect: true,
            isRequired: false,
            minDuration: 0.0,
            maxDuration: 60.0
        ),
        VoiceProfileItem(
            key: "hobby",
            displayName: "趣味について",
            allowsEffect: true,
            isRequired: false,
            minDuration: 0.0,
            maxDuration: 60.0
        )
    ]
    
    static func getItem(by key: String) -> VoiceProfileItem? {
        return items.first { $0.key == key }
    }
}

// MARK: - 保存されるボイスデータ
struct VoiceProfileData: Codable {
    var audioURL: String
    var duration: Double
    var effectUsed: String?
}

// MARK: - ユーザープロフィール
struct UserProfile: Identifiable, Codable {
    var uid: String
    var username: String
    var iconImageURL: String?
    
    var voiceProfiles: [String: VoiceProfileData]
    
    // 選択式プロフィール（単一選択）
    var profileItems: [String: String]
    
    // ハッシュタグ（最大100個）
    var hashtags: [String]
    
    // 旧形式との互換性のため残す（読み取り専用）
    var profileFreeItems: [String: [String]]
    
    // プロフィール項目の公開設定（true = 公開）
    var profileItemsVisibility: [String: Bool]
    
    var privacySettings: [String: Bool]
    var notificationSettings: [String: Bool]
    
    var blockedUserIDs: [String]
    var skippedUserIDs: [String]
    var matchedUserIDs: [String]
    var likedUserIDs: [String]
    var receivedLikeUserIDs: [String]
    
    var likeCountCurrentCycle: Int
    var cycleStartTime: Date?
    
    var isProUser: Bool
    var isAccountLocked: Bool
    var isAdmin: Bool
    var reportCount: Int
    
    var latitude: Double?
    var longitude: Double?
    var isLocationPublic: Bool
    
    var fcmToken: String?
    
    var id: String { uid }
    
    var hasNaturalVoice: Bool {
        return voiceProfiles["naturalVoice"] != nil
    }
    
    var introductionVoice: VoiceProfileData? {
        return voiceProfiles["introduction"]
    }
    
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    // 公開されている選択式プロフィール項目を取得
    var publicProfileItems: [String: String] {
        var result: [String: String] = [:]
        for (key, value) in profileItems {
            if profileItemsVisibility[key] == true && !value.isEmpty && value != "未設定" {
                result[key] = value
            }
        }
        return result
    }
    
    // 公開されている自由入力プロフィール項目を取得（旧形式互換）
    var publicProfileFreeItems: [String: [String]] {
        var result: [String: [String]] = [:]
        for (key, values) in profileFreeItems {
            if profileItemsVisibility[key] == true && !values.isEmpty {
                result[key] = values
            }
        }
        return result
    }
    
    // ハッシュタグの最大数
    static let maxHashtags = 100
    
    enum CodingKeys: String, CodingKey {
        case uid, username, iconImageURL, voiceProfiles
        case profileItems, hashtags, profileFreeItems, profileItemsVisibility
        case privacySettings, notificationSettings
        case blockedUserIDs, skippedUserIDs, matchedUserIDs
        case likedUserIDs, receivedLikeUserIDs
        case likeCountCurrentCycle, cycleStartTime
        case isProUser, isAccountLocked, isAdmin, reportCount
        case latitude, longitude, isLocationPublic, fcmToken
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        uid = try container.decode(String.self, forKey: .uid)
        username = try container.decode(String.self, forKey: .username)
        iconImageURL = try container.decodeIfPresent(String.self, forKey: .iconImageURL)
        
        voiceProfiles = try container.decodeIfPresent([String: VoiceProfileData].self, forKey: .voiceProfiles) ?? [:]
        profileItems = try container.decodeIfPresent([String: String].self, forKey: .profileItems) ?? [:]
        
        // ハッシュタグを読み込み（なければ旧形式から変換）
        if let tags = try container.decodeIfPresent([String].self, forKey: .hashtags) {
            hashtags = tags
        } else {
            // 旧形式のprofileFreeItemsからハッシュタグを生成
            let oldFreeItems = try container.decodeIfPresent([String: [String]].self, forKey: .profileFreeItems) ?? [:]
            var convertedTags: [String] = []
            for (_, values) in oldFreeItems {
                convertedTags.append(contentsOf: values)
            }
            hashtags = Array(Set(convertedTags)).prefix(UserProfile.maxHashtags).map { $0 }
        }
        
        profileFreeItems = try container.decodeIfPresent([String: [String]].self, forKey: .profileFreeItems) ?? [:]
        profileItemsVisibility = try container.decodeIfPresent([String: Bool].self, forKey: .profileItemsVisibility) ?? [:]
        privacySettings = try container.decodeIfPresent([String: Bool].self, forKey: .privacySettings) ?? [:]
        notificationSettings = try container.decodeIfPresent([String: Bool].self, forKey: .notificationSettings) ?? ["like": true, "match": true, "message": true]
        
        blockedUserIDs = try container.decodeIfPresent([String].self, forKey: .blockedUserIDs) ?? []
        skippedUserIDs = try container.decodeIfPresent([String].self, forKey: .skippedUserIDs) ?? []
        matchedUserIDs = try container.decodeIfPresent([String].self, forKey: .matchedUserIDs) ?? []
        likedUserIDs = try container.decodeIfPresent([String].self, forKey: .likedUserIDs) ?? []
        receivedLikeUserIDs = try container.decodeIfPresent([String].self, forKey: .receivedLikeUserIDs) ?? []
        
        likeCountCurrentCycle = try container.decodeIfPresent(Int.self, forKey: .likeCountCurrentCycle) ?? 0
        cycleStartTime = try container.decodeIfPresent(Date.self, forKey: .cycleStartTime)
        
        isProUser = try container.decodeIfPresent(Bool.self, forKey: .isProUser) ?? false
        isAccountLocked = try container.decodeIfPresent(Bool.self, forKey: .isAccountLocked) ?? false
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        reportCount = try container.decodeIfPresent(Int.self, forKey: .reportCount) ?? 0
        
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        isLocationPublic = try container.decodeIfPresent(Bool.self, forKey: .isLocationPublic) ?? false
        
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
    }
    
    init(
        uid: String,
        username: String,
        iconImageURL: String? = nil,
        voiceProfiles: [String: VoiceProfileData] = [:],
        profileItems: [String: String] = [:],
        hashtags: [String] = [],
        profileFreeItems: [String: [String]] = [:],
        profileItemsVisibility: [String: Bool] = [:],
        privacySettings: [String: Bool] = [:],
        notificationSettings: [String: Bool] = ["like": true, "match": true, "message": true],
        blockedUserIDs: [String] = [],
        skippedUserIDs: [String] = [],
        matchedUserIDs: [String] = [],
        likedUserIDs: [String] = [],
        receivedLikeUserIDs: [String] = [],
        likeCountCurrentCycle: Int = 0,
        cycleStartTime: Date? = nil,
        isProUser: Bool = false,
        isAccountLocked: Bool = false,
        isAdmin: Bool = false,
        reportCount: Int = 0,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isLocationPublic: Bool = false,
        fcmToken: String? = nil
    ) {
        self.uid = uid
        self.username = username
        self.iconImageURL = iconImageURL
        self.voiceProfiles = voiceProfiles
        self.profileItems = profileItems
        self.hashtags = hashtags
        self.profileFreeItems = profileFreeItems
        self.profileItemsVisibility = profileItemsVisibility
        self.privacySettings = privacySettings
        self.notificationSettings = notificationSettings
        self.blockedUserIDs = blockedUserIDs
        self.skippedUserIDs = skippedUserIDs
        self.matchedUserIDs = matchedUserIDs
        self.likedUserIDs = likedUserIDs
        self.receivedLikeUserIDs = receivedLikeUserIDs
        self.likeCountCurrentCycle = likeCountCurrentCycle
        self.cycleStartTime = cycleStartTime
        self.isProUser = isProUser
        self.isAccountLocked = isAccountLocked
        self.isAdmin = isAdmin
        self.reportCount = reportCount
        self.latitude = latitude
        self.longitude = longitude
        self.isLocationPublic = isLocationPublic
        self.fcmToken = fcmToken
    }
}

// MARK: - マッチング情報
struct UserMatch: Identifiable, Codable {
    @DocumentID var id: String?
    var user1ID: String
    var user2ID: String
    var lastMessageDate: Date
    var matchDate: Date
}

// MARK: - いいね
struct Like: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUserID: String
    var toUserID: String
    var createdAt: Date
    var status: LikeStatus
    
    // ボイスいいね用
    var voiceURL: String?
    var voiceDuration: Double?
}

enum LikeStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
}

// MARK: - ボイスメッセージ
struct VoiceMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var senderID: String
    var audioURL: String
    var duration: Double
    var timestamp: Date
    var isRead: Bool
    var effectUsed: String?
}

// MARK: - 通報
struct Report: Identifiable, Codable {
    @DocumentID var id: String?
    var reporterID: String
    var targetID: String
    var reason: String
    var comment: String
    var audioURL: String?
    var timestamp: Date
}
