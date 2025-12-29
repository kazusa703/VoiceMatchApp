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
    
    // ハッシュタグサジェスト用キャッシュ
    @Published var hashtagSuggestions: [String] = []
    
    // ハッシュタグフィルター
    var hashtagFilter: [String] = []
    
    // 旧形式との互換性（使用しない場合も残す）
    var freeInputFilters: [String: [String]] = [:]
    var suggestionsCache: [String: [String]] = [:]
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - ハッシュタグサジェスト取得
    
    func fetchHashtagSuggestions() async {
        // 全ユーザーのハッシュタグを収集してサジェスト用にキャッシュ
        do {
            let snapshot = try await db.collection("users")
                .limit(to: 500)
                .getDocuments()
            
            var allHashtags: Set<String> = []
            
            for doc in snapshot.documents {
                if let user = try? doc.data(as: UserProfile.self) {
                    allHashtags.formUnion(user.hashtags)
                    
                    // 旧形式のデータも収集（互換性のため）
                    for (_, values) in user.profileFreeItems {
                        allHashtags.formUnion(values)
                    }
                }
            }
            
            // 配列に変換してキャッシュ（ソート済み）
            self.hashtagSuggestions = allHashtags.sorted()
            print("🏷️ ハッシュタグサジェスト取得完了: \(self.hashtagSuggestions.count)件")
            
        } catch {
            print("🏷️ ハッシュタグサジェスト取得エラー: \(error)")
        }
    }
    
    // 旧API互換性のため残す
    func getSuggestionsForKey(_ key: String) -> [String] {
        return suggestionsCache[key] ?? []
    }
    
    func fetchSuggestions() async {
        // ハッシュタグ形式と統合
        await fetchHashtagSuggestions()
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
    
    // MARK: - ボイス付きいいね送信
    
    func sendVoiceLike(toUserID: String, voiceURL: URL, duration: Double) async -> Bool {
        guard let fromUserID = currentUserProfile?.uid else { return false }
        guard canSendLike() else { return false }
        
        do {
            // ボイスファイルをStorageにアップロード
            let audioData = try Data(contentsOf: voiceURL)
            let voicePath = "voice_likes/\(fromUserID)_\(toUserID).m4a"
            let ref = storage.reference().child(voicePath)
            _ = try await ref.putDataAsync(audioData)
            let downloadURL = try await ref.downloadURL()
            
            // Likeドキュメントを作成（ボイス情報付き）
            let like = Like(
                fromUserID: fromUserID,
                toUserID: toUserID,
                createdAt: Date(),
                status: .pending,
                voiceURL: downloadURL.absoluteString,
                voiceDuration: duration
            )
            
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
            
            print("✅ ボイス付きいいね送信完了")
            return true
        } catch {
            print("ボイス付きいいね送信エラー: \(error)")
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
            
            receivedLikes.removeAll { $0.fromUserID == fromUserID }
            
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
            receivedLikes.removeAll { $0.fromUserID == fromUserID }
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
    }
    
    func fetchOtherUserProfile(uid: String) async throws -> UserProfile {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        return try snapshot.data(as: UserProfile.self)
    }
    
    // MARK: - プロフィール更新
    
    func updateUserProfile(profile: UserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
        self.currentUserProfile = profile
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
        let myUID = currentUserProfile?.uid
        let isGuestMode = (myUID == nil)
        
        print("🔍 ========== 探すユーザー取得開始 ==========")
        print("🔍 モード: \(isGuestMode ? "ゲスト" : "通常")")
        print("🔍 ハッシュタグフィルター: \(hashtagFilter)")
        
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
                
                if isGuestMode {
                    // ゲストモードは地声があるユーザーのみ
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
                    
                    // ハッシュタグフィルター（AND検索）
                    var matchesHashtagFilter = true
                    if !hashtagFilter.isEmpty {
                        for filterTag in hashtagFilter {
                            let normalizedFilter = filterTag
                                .replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: "　", with: "")
                                .lowercased()
                            
                            let found = user.hashtags.contains { userTag in
                                let normalizedUserTag = userTag
                                    .replacingOccurrences(of: " ", with: "")
                                    .replacingOccurrences(of: "　", with: "")
                                    .lowercased()
                                return normalizedUserTag.contains(normalizedFilter)
                            }
                            
                            if !found {
                                matchesHashtagFilter = false
                                break
                            }
                        }
                    }
                    
                    // 旧形式フィルター（互換性のため）
                    var matchesFreeInputFilters = true
                    for (key, filterValues) in freeInputFilters {
                        if filterValues.isEmpty { continue }
                        
                        let userValues = user.profileFreeItems[key] ?? []
                        for filterValue in filterValues {
                            if !userValues.contains(where: { $0.lowercased().contains(filterValue.lowercased()) }) {
                                matchesFreeInputFilters = false
                                break
                            }
                        }
                        if !matchesFreeInputFilters { break }
                    }
                    
                    if matchesHashtagFilter && matchesFreeInputFilters {
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
        
        // ハッシュタグの共通点
        let myHashtags = Set(myProfile.hashtags.map { $0.lowercased() })
        let userHashtags = Set(user.hashtags.map { $0.lowercased() })
        let commonHashtags = myHashtags.intersection(userHashtags)
        count += commonHashtags.count
        
        // 旧形式の共通点（互換性のため）
        for (key, myValues) in myProfile.profileFreeItems {
            if let userValues = user.profileFreeItems[key] {
                let common = Set(myValues.map { $0.lowercased() }).intersection(Set(userValues.map { $0.lowercased() }))
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
    
    func unblockUser(targetUID: String) async {
        guard let uid = currentUserProfile?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "blockedUserIDs": FieldValue.arrayRemove([targetUID])
            ])
            currentUserProfile?.blockedUserIDs.removeAll { $0 == targetUID }
        } catch {
            print("ブロック解除エラー: \(error)")
        }
    }
    
    func getBlockedUsers() async -> [UserProfile] {
        guard let blockedIDs = currentUserProfile?.blockedUserIDs, !blockedIDs.isEmpty else {
            return []
        }
        return await fetchUsersByIDs(uids: blockedIDs)
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
    
    // MARK: - アカウント削除（完全削除）
    
    func deleteUserAccount(uid: String) async throws {
        print("🗑️ [deleteUserAccount] アカウント削除開始: \(uid)")
        
        // 1. ユーザードキュメントを削除
        try await db.collection("users").document(uid).delete()
        
        // 2. アイコン画像を削除
        try? await storage.reference().child("icons/\(uid).jpg").delete()
        
        // 3. ボイスプロフィールを削除
        for item in VoiceProfileConstants.items {
            try? await storage.reference().child("voice_profiles/\(uid)/\(item.key).m4a").delete()
        }
        
        // 4. 送信したいいねを削除
        let sentLikes = try await db.collection("likes")
            .whereField("fromUserID", isEqualTo: uid)
            .getDocuments()
        for doc in sentLikes.documents {
            try? await doc.reference.delete()
        }
        
        // 5. 受信したいいねを削除
        let receivedLikesQuery = try await db.collection("likes")
            .whereField("toUserID", isEqualTo: uid)
            .getDocuments()
        for doc in receivedLikesQuery.documents {
            try? await doc.reference.delete()
        }
        
        // 6. マッチとメッセージを削除
        let matches1 = try await db.collection("matches")
            .whereField("user1ID", isEqualTo: uid)
            .getDocuments()
        let matches2 = try await db.collection("matches")
            .whereField("user2ID", isEqualTo: uid)
            .getDocuments()
        
        for doc in matches1.documents + matches2.documents {
            let matchID = doc.documentID
            
            // マッチ内のメッセージを削除（音声ファイルも）
            let messages = try await db.collection("matches").document(matchID)
                .collection("messages").getDocuments()
            for msgDoc in messages.documents {
                // 音声URLがあればStorageからも削除
                if let msg = try? msgDoc.data(as: VoiceMessage.self),
                   let audioPath = extractStoragePath(from: msg.audioURL) {
                    try? await storage.reference().child(audioPath).delete()
                }
                try? await msgDoc.reference.delete()
            }
            
            // マッチドキュメントを削除
            try? await doc.reference.delete()
        }
        
        // 7. 通報を削除（自分が通報したもの）
        let reports = try await db.collection("reports")
            .whereField("reporterID", isEqualTo: uid)
            .getDocuments()
        for doc in reports.documents {
            try? await doc.reference.delete()
        }
        
        print("✅ [deleteUserAccount] アカウント削除完了")
        
        // ローカル状態をクリア
        currentUserProfile = nil
        discoveryUsers = []
        receivedLikes = []
    }
    
    // StorageのURLからパスを抽出
    private func extractStoragePath(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              url.host?.contains("firebasestorage") == true else {
            return nil
        }
        
        // Firebase Storage URLからパスを抽出
        // 例: https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Ffile?...
        if let range = urlString.range(of: "/o/"),
           let endRange = urlString.range(of: "?") {
            let encodedPath = String(urlString[range.upperBound..<endRange.lowerBound])
            return encodedPath.removingPercentEncoding
        }
        return nil
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
