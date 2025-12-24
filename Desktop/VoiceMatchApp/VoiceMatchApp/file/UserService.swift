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
    
    func deleteUserAccount(uid: String) async throws {
            // Firestoreのユーザーデータを削除
            try await Firestore.firestore().collection("users").document(uid).delete()
            
            // ※必要に応じて、サブコレクションや関連データ（Storageの画像など）の削除処理もここに記述します
        }
    
    // MARK: - ユーザー情報取得・作成
    func fetchOrCreateUserProfile(uid: String) async throws {
        let docRef = db.collection("users").document(uid)
        let document = try await docRef.getDocument()
        if document.exists {
            if let data = document.data() {
                let user = decodeUser(from: data, uid: uid)
                // データ補正
                if user.cycleStartTime == nil {
                    var updatedUser = user
                    updatedUser.cycleStartTime = Date()
                    updatedUser.matchCountCurrentCycle = 0
                    try await docRef.setData(from: updatedUser, merge: true)
                }
                DispatchQueue.main.async { self.currentUserProfile = user }
            }
        } else {
            let newUser = UserProfile(
                uid: uid,
                username: "ゲストユーザー",
                profileItems: [:],
                privacySettings: [:],
                notificationSettings: ["approach": true, "message": true],
                cycleStartTime: Date(),
                maxMatchesPerCycle: 5
            )
            try await docRef.setData(from: newUser)
            DispatchQueue.main.async { self.currentUserProfile = newUser }
        }
        await fetchUsersForDiscovery()
    }
    
    // MARK: - 位置情報更新
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
    
    // MARK: - デコード処理
    private func decodeUser(from data: [String: Any], uid: String) -> UserProfile {
        let username = data["username"] as? String ?? "ゲストユーザー"
        let profileItems = data["profileItems"] as? [String: String] ?? [:]
        let blockedUserIDs = data["blockedUserIDs"] as? [String] ?? []
        let skippedUserIDs = data["skippedUserIDs"] as? [String] ?? []
        let matchedUserIDs = data["matchedUserIDs"] as? [String] ?? []
        
        let matchCount = data["matchCountCurrentCycle"] as? Int ?? 0
        let isPro = data["isProUser"] as? Bool ?? false
        let maxMatches = data["maxMatchesPerCycle"] as? Int ?? 5
        let imageURL = data["profileImageURL"] as? String
        let bioURL = data["bioAudioURL"] as? String
        let fcmToken = data["fcmToken"] as? String
        
        let bio = data["bio"] as? String ?? ""
        let privacySettings = data["privacySettings"] as? [String: Bool] ?? [:]
        let notificationSettings = data["notificationSettings"] as? [String: Bool] ?? ["approach": true, "message": true]
        
        let cycleStartTimestamp = data["cycleStartTime"] as? Timestamp
        let cycleStartTime = cycleStartTimestamp?.dateValue()
        
        // 位置情報の取得
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
        
        // 各フラグの代入
        profile.latitude = latitude
        profile.longitude = longitude
        profile.isLocationPublic = isLocationPublic
        profile.reportCount = data["reportCount"] as? Int ?? 0
        profile.isAccountLocked = data["isAccountLocked"] as? Bool ?? false
        profile.isAdmin = data["isAdmin"] as? Bool ?? false
        
        return profile
    }
    
    // MARK: - 通知設定の更新
    func updateNotificationSettings(key: String, isOn: Bool) {
        guard var user = currentUserProfile else { return }
        
        var newSettings = user.notificationSettings
        newSettings[key] = isOn
        user.notificationSettings = newSettings
        
        self.currentUserProfile = user
        
        let docRef = db.collection("users").document(user.uid)
        docRef.updateData(["notificationSettings": newSettings]) { error in
            if let error = error {
                print("通知設定の更新エラー: \(error)")
            }
        }
    }
    
    // MARK: - 画像・音声アップロード
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
    
    // MARK: - デバッグ用
    func resetDiscoveryHistory() async {
        guard var user = currentUserProfile else { return }
        user.skippedUserIDs = []
        user.matchedUserIDs = []
        try? await updateUserProfile(profile: user)
        await fetchUsersForDiscovery()
        print("DEBUG: 履歴をリセットしました")
    }
    
    // MARK: - ユーザー検索（発見タブ用）
    func fetchUsersForDiscovery() async {
        guard let currentUID = currentUserProfile?.uid else { return }
        do {
            let snapshot = try await db.collection("users")
                .whereField("uid", isNotEqualTo: currentUID)
                .limit(to: 50)
                .getDocuments()
            
            let users = snapshot.documents.compactMap { doc -> UserProfile? in
                return self.decodeUser(from: doc.data(), uid: doc.documentID)
            }
            
            await MainActor.run {
                guard let currentUser = self.currentUserProfile else { return }
                let blockedIDs = Set(currentUser.blockedUserIDs)
                self.discoveryUsers = users.filter { user in
                    return user.uid != currentUID && !blockedIDs.contains(user.uid)
                }
            }
        } catch {
            print("DEBUG: ユーザー取得エラー \(error)")
        }
    }
    
    func skipUser(targetUID: String) async {
        guard var user = currentUserProfile else { return }
        if !user.skippedUserIDs.contains(targetUID) {
            user.skippedUserIDs.append(targetUID)
            await MainActor.run { self.currentUserProfile = user }
            try? await updateUserProfile(profile: user)
        }
    }
    
    /// ★追加: スキップを解除して、再度「探す」に表示されるようにする
    func unskipUser(targetUID: String) async {
        guard var user = currentUserProfile else { return }
        if let index = user.skippedUserIDs.firstIndex(of: targetUID) {
            user.skippedUserIDs.remove(at: index)
            try? await updateUserProfile(profile: user)
            await MainActor.run { self.currentUserProfile = user }
        }
    }
    
    func fetchOtherUserProfile(uid: String) async throws -> UserProfile {
        let doc = try await db.collection("users").document(uid).getDocument()
        guard let data = doc.data() else { throw NSError(domain: "App", code: -1) }
        return decodeUser(from: data, uid: uid)
    }
    
    /// ★追加: 指定された複数のUIDからプロフィールを一括取得する
    func fetchUsersByIDs(uids: [String]) async -> [UserProfile] {
        var users: [UserProfile] = []
        for uid in uids {
            if let user = try? await fetchOtherUserProfile(uid: uid) {
                users.append(user)
            }
        }
        return users
    }

    func canSendApproach() -> Bool {
        guard let user = currentUserProfile else { return false }
        
        if let start = user.cycleStartTime {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 12 * 60 * 60 { return true }
        } else {
            return true
        }
        
        let limit = user.isProUser ? 50 : 5
        return user.matchCountCurrentCycle < limit
    }
    
    @MainActor
    func incrementMatchCount() async throws {
        guard var user = currentUserProfile else { return }
        let now = Date()
        
        if let start = user.cycleStartTime {
            let elapsed = now.timeIntervalSince(start)
            if elapsed > 12 * 60 * 60 {
                user.matchCountCurrentCycle = 1
                user.cycleStartTime = now
            } else {
                user.matchCountCurrentCycle += 1
            }
        } else {
            user.matchCountCurrentCycle = 1
            user.cycleStartTime = now
        }
        
        try await updateUserProfile(profile: user)
    }
    
    @MainActor
    func syncProStatus(isPro: Bool) async {
        guard var user = currentUserProfile else { return }
        if user.isProUser != isPro {
            user.isProUser = isPro
            user.maxMatchesPerCycle = isPro ? 50 : 5
            try? await updateUserProfile(profile: user)
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
    
    // MARK: - 通報・ペナルティシステム
    
    /// 通報
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
            // 1. レポートを保存
            try await db.collection("reports").addDocument(data: reportData)
            
            // 2. 相手の通報カウントを +1 し、必要ならロックする
            let targetRef = db.collection("users").document(targetUID)
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let targetDoc: DocumentSnapshot
                do {
                    targetDoc = try transaction.getDocument(targetRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
                
                let currentCount = targetDoc.data()?["reportCount"] as? Int ?? 0
                let newCount = currentCount + 1
                
                var updateData: [String: Any] = ["reportCount": newCount]
                
                // 自動ペナルティ: 10回でロック
                if newCount >= 10 {
                    updateData["isAccountLocked"] = true
                }
                
                transaction.updateData(updateData, forDocument: targetRef)
                return nil
            }
        } catch {
            print("通報処理エラー: \(error)")
        }
    }
    
    /// 管理者用: 注意勧告を送信
    func sendWarningNotification(targetUID: String) async {
        let warningData: [String: Any] = [
            "title": "運営からの注意勧告",
            "body": "利用規約に抵触する行為が確認されました。改善されない場合はアカウントを停止します。",
            "timestamp": FieldValue.serverTimestamp(),
            "type": "warning"
        ]
        
        do {
            try await db.collection("users")
                .document(targetUID)
                .collection("system_notifications")
                .addDocument(data: warningData)
            print("DEBUG: 注意勧告を送信しました - \(targetUID)")
        } catch {
            print("注意勧告の送信エラー: \(error)")
        }
    }
    
    /// アカウントロック状態の手動更新
    @MainActor
    func updateAccountLockStatus(targetUID: String, isLocked: Bool) async {
        do {
            try await db.collection("users").document(targetUID).updateData([
                "isAccountLocked": isLocked
            ])
            print("DEBUG: ユーザー \(targetUID) のロック状態を \(isLocked) に更新しました")
        } catch {
            print("DEBUG: ロック状態の更新に失敗: \(error)")
        }
    }
    
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
