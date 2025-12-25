import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine
import UIKit
import GoogleSignIn
import CoreLocation

class UserService: ObservableObject {
    @Published var currentUserProfile: UserProfile?
    @Published var discoveryUsers: [UserProfile] = []
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - アカウント削除
    func deleteUserAccount(uid: String) async throws {
        let imageRef = storage.reference().child("profile_images/\(uid).jpg")
        let voiceRef = storage.reference().child("bio_voices/\(uid).m4a")
        try? await imageRef.delete()
        try? await voiceRef.delete()
        try await db.collection("users").document(uid).delete()
    }
    
    // MARK: - ユーザー情報取得・作成
    func fetchOrCreateUserProfile(uid: String) async throws {
        let docRef = db.collection("users").document(uid)
        let document = try await docRef.getDocument()
        
        var profile: UserProfile
        
        if document.exists, let data = document.data() {
            profile = decodeUser(from: data, uid: uid)
        } else {
            // 新規作成
            profile = UserProfile(
                uid: uid,
                username: "ゲストユーザー",
                profileItems: [:],
                privacySettings: [:],
                notificationSettings: ["approach": true, "match": true, "message": true],
                cycleStartTime: Date(),
                maxMatchesPerCycle: 5
            )
            try await docRef.setData(from: profile)
        }
        
        // 取得時にリセット判定を実行
        profile = checkAndResetSentCount(profile: profile)
        
        // リセットが発生した可能性があるため、最新状態をDBへ保存
        try await updateUserProfile(profile: profile)
        
        await MainActor.run { self.currentUserProfile = profile }
        
        // 発見タブ用のユーザーもロード
        await fetchUsersForDiscovery()
    }
    
    // MARK: - アプローチ制限ロジック
    
    // 12時間経過していたら送信カウントをリセット
    private func checkAndResetSentCount(profile: UserProfile) -> UserProfile {
        var updatedProfile = profile
        let now = Date()
        
        if let lastReset = updatedProfile.cycleStartTime {
            let interval = now.timeIntervalSince(lastReset)
            if interval >= 12 * 60 * 60 { // 12時間以上経過
                updatedProfile.matchCountCurrentCycle = 0
                updatedProfile.cycleStartTime = now
                print("DEBUG: 12時間が経過したため、送信カウントをリセットしました")
            }
        } else {
            updatedProfile.cycleStartTime = now
            updatedProfile.matchCountCurrentCycle = 0
        }
        
        return updatedProfile
    }
    
    // アプローチ送信可能かチェック
    func canSendApproach() -> Bool {
        guard let user = currentUserProfile else { return false }
        
        if user.isProUser { return true }
        
        // リセット時間経過もチェック
        if let start = user.cycleStartTime, Date().timeIntervalSince(start) > 12 * 60 * 60 {
            return true
        }
        
        let limit = 5
        return user.matchCountCurrentCycle < limit
    }
    
    // アプローチ送信時のみカウントを増やす
    @MainActor
    func incrementApproachCount() async throws {
        guard var user = currentUserProfile else { return }
        
        // まずリセットが必要かチェック
        user = checkAndResetSentCount(profile: user)
        
        // カウントアップ
        user.matchCountCurrentCycle += 1
        user.maxMatchesPerCycle = user.isProUser ? 50 : 5
        
        try await updateUserProfile(profile: user)
    }
    
    // 互換性のため残す
    @MainActor
    func incrementMatchCount() async throws {
        try await incrementApproachCount()
    }
    
    // MARK: - 位置情報
    
    func updateLocationPublicStatus(isOn: Bool) {
        guard let uid = currentUserProfile?.uid else { return }
        Task {
            try? await db.collection("users").document(uid).updateData(["isLocationPublic": isOn])
            await MainActor.run { self.currentUserProfile?.isLocationPublic = isOn }
        }
    }

    func updateUserLocation(location: CLLocation) async {
        guard let uid = currentUserProfile?.uid else { return }
        let data: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude
        ]
        try? await db.collection("users").document(uid).updateData(data)
    }
    
    func updateFCMToken(token: String) {
        guard let uid = currentUserProfile?.uid else { return }
        db.collection("users").document(uid).updateData(["fcmToken": token])
    }
    
    // MARK: - デコード
    
    private func decodeUser(from data: [String: Any], uid: String) -> UserProfile {
        let username = data["username"] as? String ?? "ゲストユーザー"
        let profileItems = data["profileItems"] as? [String: String] ?? [:]
        let blockedUserIDs = data["blockedUserIDs"] as? [String] ?? []
        let skippedUserIDs = data["skippedUserIDs"] as? [String] ?? []
        let matchedUserIDs = data["matchedUserIDs"] as? [String] ?? []
        
        let matchCount = data["matchCountCurrentCycle"] as? Int ?? 0
        let isPro = data["isProUser"] as? Bool ?? false
        let maxMatches = isPro ? 50 : 5
        
        let imageURL = data["profileImageURL"] as? String
        let bioURL = data["bioAudioURL"] as? String
        let fcmToken = data["fcmToken"] as? String
        
        let bio = data["bio"] as? String ?? ""
        let privacySettings = data["privacySettings"] as? [String: Bool] ?? [:]
        let notificationSettings = data["notificationSettings"] as? [String: Bool] ?? ["approach": true, "match": true, "message": true]
        
        let cycleStartTimestamp = data["cycleStartTime"] as? Timestamp
        let cycleStartTime = cycleStartTimestamp?.dateValue()
        
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let isLocationPublic = data["isLocationPublic"] as? Bool ?? false
        
        var profile = UserProfile(
            uid: uid,
            username: username,
            profileImageURL: imageURL,
            bioAudioURL: bioURL,
            bio: bio,
            profileItems: profileItems,
            privacySettings: privacySettings,
            notificationSettings: notificationSettings,
            blockedUserIDs: blockedUserIDs,
            skippedUserIDs: skippedUserIDs,
            matchedUserIDs: matchedUserIDs,
            matchCountCurrentCycle: matchCount,
            lastMatchDate: nil,
            isProUser: isPro,
            fcmToken: fcmToken,
            cycleStartTime: cycleStartTime,
            maxMatchesPerCycle: maxMatches
        )
        
        profile.latitude = latitude
        profile.longitude = longitude
        profile.isLocationPublic = isLocationPublic
        profile.reportCount = data["reportCount"] as? Int ?? 0
        profile.isAccountLocked = data["isAccountLocked"] as? Bool ?? false
        profile.isAdmin = data["isAdmin"] as? Bool ?? false
        
        return profile
    }
    
    // MARK: - 設定更新
    
    func updateNotificationSettings(key: String, isOn: Bool) {
        guard var user = currentUserProfile else { return }
        var newSettings = user.notificationSettings
        newSettings[key] = isOn
        user.notificationSettings = newSettings
        self.currentUserProfile = user
        
        db.collection("users").document(user.uid).updateData(["notificationSettings": newSettings])
    }
    
    // MARK: - アップロード
    
    func uploadProfileImage(image: UIImage) async throws {
        guard let uid = currentUserProfile?.uid, let data = image.jpegData(compressionQuality: 0.5) else { return }
        let ref = storage.reference().child("profile_images/\(uid).jpg")
        let _ = try await ref.putDataAsync(data)
        let url = try await ref.downloadURL()
        if var user = currentUserProfile {
            user.profileImageURL = url.absoluteString
            try await updateUserProfile(profile: user)
        }
    }
    
    func uploadBioVoice(audioURL: URL) async throws {
        guard let uid = currentUserProfile?.uid, let data = try? Data(contentsOf: audioURL) else { return }
        let ref = storage.reference().child("bio_voices/\(uid).m4a")
        let _ = try await ref.putDataAsync(data)
        let url = try await ref.downloadURL()
        if var user = currentUserProfile {
            user.bioAudioURL = url.absoluteString
            try await updateUserProfile(profile: user)
        }
    }
    
    func updateUserProfile(profile: UserProfile) async throws {
        try db.collection("users").document(profile.uid).setData(from: profile, merge: true)
        await MainActor.run { self.currentUserProfile = profile }
    }
    
    // MARK: - Discovery
    
    func resetDiscoveryHistory() async {
        guard var user = currentUserProfile else { return }
        print("DEBUG: 履歴リセットを開始します...")
        user.skippedUserIDs = []
        user.matchedUserIDs = []
        try? await updateUserProfile(profile: user)
        await fetchUsersForDiscovery()
        print("DEBUG: 履歴をリセットし、再フェッチしました")
    }
    
    func fetchUsersForDiscovery() async {
        print("DEBUG: fetchUsersForDiscovery: 開始")
        guard let currentUID = currentUserProfile?.uid else {
            print("DEBUG: エラー: currentUserProfileがnilです")
            return
        }
        
        do {
            print("DEBUG: Firestoreから最大50件のユーザーを取得します...")
            let snapshot = try await db.collection("users")
                .limit(to: 50)
                .getDocuments()
            
            let users = snapshot.documents.compactMap { doc -> UserProfile? in
                return self.decodeUser(from: doc.data(), uid: doc.documentID)
            }
            
            await MainActor.run {
                guard let currentUser = self.currentUserProfile else { return }
                let blockedIDs = Set(currentUser.blockedUserIDs)
                
                print("DEBUG: フィルタリング開始 (自分ID: \(currentUID))")
                
                self.discoveryUsers = users.filter { user in
                    let isMe = (user.uid == currentUID)
                    if isMe { return false }
                    
                    let isBlockedByMe = blockedIDs.contains(user.uid)
                    if isBlockedByMe { return false }
                    
                    if user.isAccountLocked { return false }
                    
                    return true
                }
                
                print("DEBUG: fetchUsersForDiscovery完了。リスト保持数: \(self.discoveryUsers.count)人")
            }
        } catch {
            print("DEBUG: ユーザー取得エラー: \(error)")
        }
    }
    
    // MARK: - Skip / Block
    
    func skipUser(targetUID: String) async {
        guard var user = currentUserProfile else { return }
        if !user.skippedUserIDs.contains(targetUID) {
            user.skippedUserIDs.append(targetUID)
            await MainActor.run { self.currentUserProfile = user }
            try? await updateUserProfile(profile: user)
            print("DEBUG: ユーザーをスキップしました: \(targetUID)")
        }
    }
    
    func unskipUser(targetUID: String) async {
        guard var user = currentUserProfile else { return }
        if let index = user.skippedUserIDs.firstIndex(of: targetUID) {
            user.skippedUserIDs.remove(at: index)
            try? await updateUserProfile(profile: user)
            await MainActor.run { self.currentUserProfile = user }
        }
    }
    
    func blockUser(targetUID: String) async {
        guard var user = currentUserProfile else { return }
        if !user.blockedUserIDs.contains(targetUID) {
            user.blockedUserIDs.append(targetUID)
            try? await updateUserProfile(profile: user)
            await MainActor.run { self.discoveryUsers.removeAll { $0.uid == targetUID } }
        }
    }
    
    // MARK: - Fetch Others
    
    func fetchOtherUserProfile(uid: String) async throws -> UserProfile {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else { throw NSError(domain: "App", code: -1) }
        return decodeUser(from: data, uid: uid)
    }
    
    func fetchUsersByIDs(uids: [String]) async -> [UserProfile] {
        var users: [UserProfile] = []
        for uid in uids {
            if let user = try? await fetchOtherUserProfile(uid: uid) {
                users.append(user)
            }
        }
        return users
    }
    
    // MARK: - Pro Status
    
    @MainActor
    func syncProStatus(isPro: Bool) async {
        guard var user = currentUserProfile else { return }
        if user.isProUser != isPro {
            user.isProUser = isPro
            user.maxMatchesPerCycle = isPro ? 50 : 5
            try? await updateUserProfile(profile: user)
        }
    }
    
    // MARK: - 通報・管理
    
    func reportUser(targetUID: String, reason: String, comment: String, audioURL: String?) async {
        guard let myUID = currentUserProfile?.uid else { return }
        
        let reportData: [String: Any] = [
            "reporterID": myUID,
            "targetID": targetUID,
            "reason": reason,
            "comment": comment,
            "audioURL": audioURL ?? "",
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("reports").addDocument(data: reportData)
            let targetRef = db.collection("users").document(targetUID)
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let targetDoc: DocumentSnapshot
                do { targetDoc = try transaction.getDocument(targetRef) } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                let currentCount = targetDoc.data()?["reportCount"] as? Int ?? 0
                let newCount = currentCount + 1
                var updateData: [String: Any] = ["reportCount": newCount]
                if newCount >= 10 { updateData["isAccountLocked"] = true }
                transaction.updateData(updateData, forDocument: targetRef)
                return nil
            }
        } catch { print("通報処理エラー: \(error)") }
    }
    
    func sendWarningNotification(targetUID: String) async {
        // TODO: 警告通知の実装
    }
    
    @MainActor
    func updateAccountLockStatus(targetUID: String, isLocked: Bool) async {
        try? await db.collection("users").document(targetUID).updateData(["isAccountLocked": isLocked])
    }
    
    // MARK: - Google Sign In
    
    @MainActor
    func signInWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString else { return }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        let authResult = try await Auth.auth().signIn(with: credential)
        try await fetchOrCreateUserProfile(uid: authResult.user.uid)
    }
}
