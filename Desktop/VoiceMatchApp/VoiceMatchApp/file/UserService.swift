import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
import Combine
import SwiftUI

@MainActor
class UserService: ObservableObject {
    @Published var currentUserProfile: UserProfile?
    @Published var discoveryUsers: [UserProfile] = []
    @Published var receivedLikes: [Like] = []
    
    // 自由入力項目のサジェスト用キャッシュ
    @Published var suggestionsCache: [String: [String]] = [:]
    
    // 自由入力フィルター
    var freeInputFilters: [String: [String]] = [:]
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - サジェスト取得
    
    func getSuggestionsForKey(_ key: String) -> [String] {
        return suggestionsCache[key] ?? []
    }
    
    func fetchSuggestions() async {
        // 全ユーザーの自由入力項目を収集してサジェスト用にキャッシュ
        do {
            let snapshot = try await db.collection("users")
                .limit(to: 500)
                .getDocuments()
            
            var allSuggestions: [String: Set<String>] = [:]
            
            for doc in snapshot.documents {
                if let user = try? doc.data(as: UserProfile.self) {
                    for (key, values) in user.profileFreeItems {
                        if allSuggestions[key] == nil {
                            allSuggestions[key] = Set<String>()
                        }
                        allSuggestions[key]?.formUnion(values)
                    }
                }
            }
            
            // Setを配列に変換してキャッシュ
            for (key, values) in allSuggestions {
                suggestionsCache[key] = Array(values).sorted()
            }
            
            print("📝 サジェストキャッシュ更新完了: \(suggestionsCache.keys.count) カテゴリ")
        } catch {
            print("サジェスト取得エラー: \(error)")
        }
    }
    
    // MARK: - いいね制限
    
    func canSendLike() -> Bool {
        guard let user = currentUserProfile else { return false }
        
        if shouldResetCycle() {
            return true
        }
        
        let limit = user.isProUser ? 100 : 10
        return user.likeCountCurrentCycle < limit
    }
    
    func remainingLikes() -> Int {
        guard let user = currentUserProfile else { return 0 }
        let limit = user.isProUser ? 100 : 10
        return max(0, limit - user.likeCountCurrentCycle)
    }
    
    func maxLikesForCurrentUser() -> Int {
        return currentUserProfile?.isProUser == true ? 100 : 10
    }
    
    func timeUntilCycleReset() -> TimeInterval {
        guard let cycleStart = currentUserProfile?.cycleStartTime else { return 0 }
        let cycleEnd = cycleStart.addingTimeInterval(12 * 60 * 60)
        return max(0, cycleEnd.timeIntervalSinceNow)
    }
    
    func formattedTimeUntilReset() -> String {
        let seconds = timeUntilCycleReset()
        if seconds <= 0 { return "リセット済み" }
        
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)時間\(minutes)分"
    }
    
    private func shouldResetCycle() -> Bool {
        guard let cycleStart = currentUserProfile?.cycleStartTime else { return true }
        return Date().timeIntervalSince(cycleStart) >= 12 * 60 * 60
    }
    
    func incrementLikeCount() async {
        guard let uid = currentUserProfile?.uid else { return }
        
        var updates: [String: Any] = [:]
        
        if shouldResetCycle() {
            updates["likeCountCurrentCycle"] = 1
            updates["cycleStartTime"] = Date()
        } else {
            updates["likeCountCurrentCycle"] = FieldValue.increment(Int64(1))
        }
        
        do {
            try await db.collection("users").document(uid).updateData(updates)
            if shouldResetCycle() {
                currentUserProfile?.likeCountCurrentCycle = 1
                currentUserProfile?.cycleStartTime = Date()
            } else {
                currentUserProfile?.likeCountCurrentCycle += 1
            }
        } catch {
            print("いいねカウント更新エラー: \(error)")
        }
    }
    
    // MARK: - いいね送信
    
    func sendLike(toUserID: String) async -> Bool {
        guard let fromUserID = currentUserProfile?.uid else { return false }
        guard canSendLike() else { return false }
        
        let like = Like(
            fromUserID: fromUserID,
            toUserID: toUserID,
            createdAt: Date(),
            status: .pending
        )
        
        do {
            let likeRef = db.collection("likes").document("\(fromUserID)_\(toUserID)")
            try likeRef.setData(from: like)
            
            try await db.collection("users").document(fromUserID).updateData([
                "likedUserIDs": FieldValue.arrayUnion([toUserID])
            ])
            
            try await db.collection("users").document(toUserID).updateData([
                "receivedLikeUserIDs": FieldValue.arrayUnion([fromUserID])
            ])
            
            await incrementLikeCount()
            currentUserProfile?.likedUserIDs.append(toUserID)
            
            return true
        } catch {
            print("いいね送信エラー: \(error)")
            return false
        }
    }
    
    // MARK: - いいね承認・拒否
    
    func acceptLike(fromUserID: String) async -> UserMatch? {
        guard let myUID = currentUserProfile?.uid else { return nil }
        
        do {
            let likeRef = db.collection("likes").document("\(fromUserID)_\(myUID)")
            try await likeRef.updateData(["status": LikeStatus.accepted.rawValue])
            
            let matchID = [fromUserID, myUID].sorted().joined(separator: "_")
            let match = UserMatch(
                id: matchID,
                user1ID: fromUserID,
                user2ID: myUID,
                lastMessageDate: Date(),
                matchDate: Date()
            )
            
            let matchRef = db.collection("matches").document(matchID)
            try matchRef.setData(from: match)
            
            try await db.collection("users").document(myUID).updateData([
                "matchedUserIDs": FieldValue.arrayUnion([fromUserID]),
                "receivedLikeUserIDs": FieldValue.arrayRemove([fromUserID])
            ])
            try await db.collection("users").document(fromUserID).updateData([
                "matchedUserIDs": FieldValue.arrayUnion([myUID])
            ])
            
            currentUserProfile?.matchedUserIDs.append(fromUserID)
            currentUserProfile?.receivedLikeUserIDs.removeAll { $0 == fromUserID }
            
            return match
        } catch {
            print("いいね承認エラー: \(error)")
            return nil
        }
    }
    
    func declineLike(fromUserID: String) async {
        guard let myUID = currentUserProfile?.uid else { return }
        
        do {
            let likeRef = db.collection("likes").document("\(fromUserID)_\(myUID)")
            try await likeRef.updateData(["status": LikeStatus.declined.rawValue])
            
            try await db.collection("users").document(myUID).updateData([
                "receivedLikeUserIDs": FieldValue.arrayRemove([fromUserID])
            ])
            
            currentUserProfile?.receivedLikeUserIDs.removeAll { $0 == fromUserID }
        } catch {
            print("いいね拒否エラー: \(error)")
        }
    }
    
    func fetchReceivedLikes() async {
        guard let myUID = currentUserProfile?.uid else { return }
        
        do {
            let snapshot = try await db.collection("likes")
                .whereField("toUserID", isEqualTo: myUID)
                .whereField("status", isEqualTo: LikeStatus.pending.rawValue)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            self.receivedLikes = snapshot.documents.compactMap { try? $0.data(as: Like.self) }
        } catch {
            print("受け取ったいいね取得エラー: \(error)")
        }
    }
    
    // MARK: - ユーザープロフィール取得・作成
    
    func fetchOrCreateUserProfile(uid: String) async throws {
        let docRef = db.collection("users").document(uid)
        let snapshot = try await docRef.getDocument()
        
        if snapshot.exists {
            self.currentUserProfile = try snapshot.data(as: UserProfile.self)
        } else {
            let newUser = UserProfile(uid: uid, username: "ユーザー\(String(uid.prefix(4)))")
            try docRef.setData(from: newUser)
            self.currentUserProfile = newUser
        }
        
        // サジェスト用データを非同期で取得
        Task {
            await fetchSuggestions()
        }
    }
    
    func fetchOtherUserProfile(uid: String) async throws -> UserProfile {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        return try snapshot.data(as: UserProfile.self)
    }
    
    // MARK: - プロフィール更新
    
    func updateUserProfile(profile: UserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
        self.currentUserProfile = profile
        
        // サジェストキャッシュを更新
        Task {
            await fetchSuggestions()
        }
    }
    
    // MARK: - アイコン画像アップロード
    
    func uploadIconImage(image: UIImage) async throws {
        guard let uid = currentUserProfile?.uid,
              let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        
        let ref = storage.reference().child("icons/\(uid).jpg")
        _ = try await ref.putDataAsync(imageData)
        let url = try await ref.downloadURL()
        
        try await db.collection("users").document(uid).updateData([
            "iconImageURL": url.absoluteString
        ])
        currentUserProfile?.iconImageURL = url.absoluteString
    }
    
    // MARK: - ボイスプロフィールアップロード
    
    func uploadVoiceProfile(key: String, audioURL: URL, duration: Double, effectUsed: String?) async throws {
        guard let uid = currentUserProfile?.uid else { return }
        
        let audioData = try Data(contentsOf: audioURL)
        let ref = storage.reference().child("voice_profiles/\(uid)/\(key).m4a")
        _ = try await ref.putDataAsync(audioData)
        let url = try await ref.downloadURL()
        
        let voiceData = VoiceProfileData(
            audioURL: url.absoluteString,
            duration: duration,
            effectUsed: effectUsed
        )
        
        let encodedData = try Firestore.Encoder().encode(voiceData)
        try await db.collection("users").document(uid).updateData([
            "voiceProfiles.\(key)": encodedData
        ])
        
        currentUserProfile?.voiceProfiles[key] = voiceData
    }
    
    // MARK: - ボイスプロフィール削除
    
    func deleteVoiceProfile(key: String) async throws {
        guard let uid = currentUserProfile?.uid else { return }
        
        let ref = storage.reference().child("voice_profiles/\(uid)/\(key).m4a")
        try? await ref.delete()
        
        try await db.collection("users").document(uid).updateData([
            "voiceProfiles.\(key)": FieldValue.delete()
        ])
        
        currentUserProfile?.voiceProfiles.removeValue(forKey: key)
    }
    
    // MARK: - 探す用ユーザー取得（ゲストモード対応）
    
    func fetchUsersForDiscovery() async {
        // ゲストモードの場合は myUID が nil でも OK
        let myUID = currentUserProfile?.uid
        let isGuestMode = (myUID == nil)
        
        print("🔍 ========== 探すユーザー取得開始 ==========")
        print("🔍 モード: \(isGuestMode ? "ゲスト" : "通常")")
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("isAccountLocked", isEqualTo: false)
                .limit(to: 100)
                .getDocuments()
            
            print("🔍 Firestoreから取得したユーザー数: \(snapshot.documents.count)")
            
            var allUsers: [UserProfile] = []
            for doc in snapshot.documents {
                if let user = try? doc.data(as: UserProfile.self) {
                    allUsers.append(user)
                }
            }
            
            // フィルタリング
            var filteredUsers: [UserProfile] = []
            for user in allUsers {
                let hasNaturalVoice = user.hasNaturalVoice
                
                // ゲストモードの場合は自分チェック・ブロックチェック等をスキップ
                if isGuestMode {
                    // 地声があるユーザーのみ表示
                    if hasNaturalVoice {
                        filteredUsers.append(user)
                    }
                } else {
                    // 通常モード
                    let isSelf = user.uid == myUID
                    let isBlocked = currentUserProfile?.blockedUserIDs.contains(user.uid) ?? false
                    let isSkipped = currentUserProfile?.skippedUserIDs.contains(user.uid) ?? false
                    let alreadyMatched = currentUserProfile?.matchedUserIDs.contains(user.uid) ?? false
                    
                    // 基本フィルター
                    if isSelf || !hasNaturalVoice || isBlocked || isSkipped || alreadyMatched {
                        continue
                    }
                    
                    // 自由入力フィルター（AND検索）
                    var matchesFreeInputFilters = true
                    for (key, filterValues) in freeInputFilters {
                        if filterValues.isEmpty { continue }
                        
                        let userValues = user.profileFreeItems[key] ?? []
                        // フィルターの全ての値がユーザーの値に含まれている必要がある
                        for filterValue in filterValues {
                            if !userValues.contains(where: { $0.lowercased().contains(filterValue.lowercased()) }) {
                                matchesFreeInputFilters = false
                                break
                            }
                        }
                        if !matchesFreeInputFilters { break }
                    }
                    
                    if matchesFreeInputFilters {
                        filteredUsers.append(user)
                    }
                }
            }
            
            self.discoveryUsers = filteredUsers
            print("🔍 最終的な表示ユーザー数: \(filteredUsers.count)")
            print("🔍 ========== 探すユーザー取得完了 ==========")
            
        } catch {
            print("🔍 ユーザー取得エラー: \(error)")
        }
    }
    
    // MARK: - 共通点計算
    
    func calculateCommonPoints(with user: UserProfile) -> Int {
        guard let myProfile = currentUserProfile else { return 0 }
        var count = 0
        
        // 選択式項目の共通点
        for (key, myVal) in myProfile.profileItems {
            if let userVal = user.profileItems[key], !userVal.isEmpty && userVal == myVal && myVal != "未設定" {
                count += 1
            }
        }
        
        // 自由入力項目の共通点
        for (key, myValues) in myProfile.profileFreeItems {
            if let userValues = user.profileFreeItems[key] {
                let common = Set(myValues).intersection(Set(userValues))
                count += common.count
            }
        }
        
        return count
    }
    
    // MARK: - スキップ・ブロック
    
    func skipUser(targetUID: String) async {
        guard let uid = currentUserProfile?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "skippedUserIDs": FieldValue.arrayUnion([targetUID])
            ])
            currentUserProfile?.skippedUserIDs.append(targetUID)
            discoveryUsers.removeAll { $0.uid == targetUID }
        } catch {
            print("スキップエラー: \(error)")
        }
    }
    
    func unskipUser(targetUID: String) async {
        guard let uid = currentUserProfile?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "skippedUserIDs": FieldValue.arrayRemove([targetUID])
            ])
            currentUserProfile?.skippedUserIDs.removeAll { $0 == targetUID }
        } catch {
            print("スキップ解除エラー: \(error)")
        }
    }
    
    func blockUser(targetUID: String) async {
        guard let uid = currentUserProfile?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "blockedUserIDs": FieldValue.arrayUnion([targetUID])
            ])
            currentUserProfile?.blockedUserIDs.append(targetUID)
            discoveryUsers.removeAll { $0.uid == targetUID }
        } catch {
            print("ブロックエラー: \(error)")
        }
    }
    
    // MARK: - 通報
    
    func reportUser(targetUID: String, reason: String, comment: String, audioURL: String?) async {
        guard let uid = currentUserProfile?.uid else { return }
        
        let report = Report(
            reporterID: uid,
            targetID: targetUID,
            reason: reason,
            comment: comment,
            audioURL: audioURL,
            timestamp: Date()
        )
        
        do {
            try db.collection("reports").addDocument(from: report)
            try await db.collection("users").document(targetUID).updateData([
                "reportCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("通報エラー: \(error)")
        }
    }
    
    // MARK: - 設定更新
    
    func updateNotificationSettings(key: String, isOn: Bool) {
        guard let uid = currentUserProfile?.uid else { return }
        currentUserProfile?.notificationSettings[key] = isOn
        db.collection("users").document(uid).updateData([
            "notificationSettings.\(key)": isOn
        ])
    }
    
    func updateLocationPublicStatus(isOn: Bool) {
        guard let uid = currentUserProfile?.uid else { return }
        currentUserProfile?.isLocationPublic = isOn
        db.collection("users").document(uid).updateData([
            "isLocationPublic": isOn
        ])
    }
    
    func syncProStatus(isPro: Bool) async {
        guard let uid = currentUserProfile?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "isProUser": isPro
            ])
            currentUserProfile?.isProUser = isPro
        } catch {
            print("Pro同期エラー: \(error)")
        }
    }
    
    // MARK: - ユーザー一括取得
    
    func fetchUsersByIDs(uids: [String]) async -> [UserProfile] {
        guard !uids.isEmpty else { return [] }
        do {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: uids)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: UserProfile.self) }
        } catch {
            print("ユーザー一括取得エラー: \(error)")
            return []
        }
    }
    
    // MARK: - アカウント削除
    
    func deleteUserAccount(uid: String) async throws {
        try await db.collection("users").document(uid).delete()
        try? await storage.reference().child("icons/\(uid).jpg").delete()
        for item in VoiceProfileConstants.items {
            try? await storage.reference().child("voice_profiles/\(uid)/\(item.key).m4a").delete()
        }
    }
    
    // MARK: - 管理者機能
    
    func updateAccountLockStatus(targetUID: String, isLocked: Bool) async {
        do {
            try await db.collection("users").document(targetUID).updateData([
                "isAccountLocked": isLocked
            ])
        } catch {
            print("アカウントロック更新エラー: \(error)")
        }
    }
}
