import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import FirebaseAuth

class MessageService: ObservableObject {
    // マッチ成立後のチャット用
    @Published var matches: [UserMatch] = []
    @Published var currentMessages: [VoiceMessage] = []
    
    // マッチ前のアプローチ受信箱用
    @Published var receivedApproaches: [Message] = []
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - 【既存】マッチ後のチャット機能
    
    // ★修正: 再生回数をインクリメント（+1）するように変更
    func incrementListenCount(messageID: String, matchID: String) {
        let docRef = db.collection("matches").document(matchID).collection("messages").document(messageID)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let messageDoc: DocumentSnapshot
            do {
                try messageDoc = transaction.getDocument(docRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            let currentCount = messageDoc.data()?["listenCount"] as? Int ?? 0
            transaction.updateData(["listenCount": currentCount + 1], forDocument: docRef)
            return nil
        }) { _, error in
            if let error = error {
                print("再生回数更新エラー: \(error)")
            }
        }
    }

    func fetchMatches(for uid: String, blockedUserIDs: [String] = []) async {
        print("🔥 DEBUG: fetchMatches 開始 - UID: \(uid)")
        do {
            let s1 = try await db.collection("matches").whereField("user1ID", isEqualTo: uid).getDocuments()
            let s2 = try await db.collection("matches").whereField("user2ID", isEqualTo: uid).getDocuments()
            let m1 = s1.documents.compactMap { try? $0.data(as: UserMatch.self) }
            let m2 = s2.documents.compactMap { try? $0.data(as: UserMatch.self) }
            
            let allMatches = (m1 + m2).sorted(by: { $0.lastMessageDate > $1.lastMessageDate })
            
            await MainActor.run {
                self.matches = allMatches.filter { match in
                    let partnerID = (match.user1ID == uid) ? match.user2ID : match.user1ID
                    return !blockedUserIDs.contains(partnerID)
                }
                print("🔥 DEBUG: マッチング取得完了 - 計 \(self.matches.count) 件")
            }
        } catch {
            print("🔥 DEBUG: ❌ fetchMatches エラー: \(error)")
        }
    }

    func listenToMessages(for matchID: String) {
        db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    self.currentMessages = documents.compactMap { try? $0.data(as: VoiceMessage.self) }
                }
            }
    }
    
    // ★修正: expiresAt のセットを削除し、listenCountを初期化
    func sendVoiceMessage(senderID: String, receiverID: String, audioData: Data, duration: Double, effectName: String?, waveformSamples: [Float]) async throws {
        let matchID = [senderID, receiverID].sorted().joined(separator: "_")
        let fileName = "\(UUID().uuidString).m4a"
        let storageRef = storage.reference().child("voices/\(matchID)/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        
        let _ = try await storageRef.putDataAsync(audioData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        let messageData: [String: Any] = [
            "senderID": senderID,
            "audioURL": downloadURL.absoluteString,
            "duration": duration,
            "timestamp": FieldValue.serverTimestamp(),
            "listenCount": 0, // 初期値は0
            "effectUsed": effectName ?? "地声",
            "waveformSamples": waveformSamples
        ]
        
        let matchRef = db.collection("matches").document(matchID)
        
        try await matchRef.setData([
            "user1ID": senderID,
            "user2ID": receiverID,
            "lastMessageDate": FieldValue.serverTimestamp(),
            "matchDate": FieldValue.serverTimestamp()
        ], merge: true)
        
        try await matchRef.collection("messages").addDocument(data: messageData)
    }
    
    // MARK: - マッチ前のアプローチ機能 (Discovery)
    
    func sendApproachVoiceMessage(to receiverID: String, audioURL: URL, duration: TimeInterval) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        
        print("🔥 DEBUG: アプローチ送信処理開始")
        
        let filename = "approaches/\(UUID().uuidString).m4a"
        let storageRef = storage.reference().child(filename)
        let data = try Data(contentsOf: audioURL)
        
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        
        let _ = try await storageRef.putDataAsync(data, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        let approachData: [String: Any] = [
            "senderID": currentUID,
            "receiverID": receiverID,
            "audioURL": downloadURL.absoluteString,
            "duration": duration,
            "createdAt": FieldValue.serverTimestamp(),
            "isRead": false,
            "isMatched": false
        ]
        
        try await db.collection("messages").addDocument(data: approachData)
        print("🔥 DEBUG: ✅ アプローチ送信完了成功！ 宛先: \(receiverID)")
    }
    
    func fetchReceivedApproaches() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        
        print("🔥 DEBUG: アプローチ受信監視を開始します")
        
        // isMatched == false のものだけを取得することで、承認/拒否したものは自動で消える
        db.collection("messages")
            .whereField("receiverID", isEqualTo: currentUID)
            .whereField("isMatched", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("🔥 DEBUG: ❌ アプローチ受信エラー: \(error.localizedDescription)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                
                print("🔥 DEBUG: 📩 【\(documents.count)件】 のアプローチを受信しました")
                self.receivedApproaches = documents.compactMap { try? $0.data(as: Message.self) }
            }
    }
    
    // ★追加: アプローチを見送る（拒否する）
    func declineApproach(message: Message) async {
        guard let messageID = message.id else { return }
        
        // isMatchedをtrueにするが、マッチングテーブルには追加しない
        // これにより、fetchReceivedApproachesのクエリ条件(isMatched: false)から外れ、リストから消える
        do {
            try await db.collection("messages").document(messageID).updateData([
                "isMatched": true
            ])
            print("🔥 DEBUG: アプローチを見送りました (ID: \(messageID))")
        } catch {
            print("❌ 見送り処理エラー: \(error)")
        }
    }
    
    // マッチ承認
    func acceptApproach(message: Message) async throws -> UserMatch? {
        print("🔥 DEBUG: マッチ承認処理開始 ID: \(message.id ?? "")")
        
        guard let messageID = message.id else { return nil }
        
        // 1. アプローチ済みフラグを立てる (これでアプローチリストから消える)
        try await db.collection("messages").document(messageID).updateData([
            "isMatched": true
        ])
        
        // 2. マッチング情報の作成
        let matchID = [message.senderID, message.receiverID].sorted().joined(separator: "_")
        let matchRef = db.collection("matches").document(matchID)
        
        // チャットルームを作成
        let matchData: [String: Any] = [
            "user1ID": message.senderID,
            "user2ID": message.receiverID,
            "lastMessageDate": FieldValue.serverTimestamp(),
            "matchDate": FieldValue.serverTimestamp()
        ]
        try await matchRef.setData(matchData, merge: true)
        
        // 3. アプローチボイスをチャットにコピー
        // ★修正: expiresAt を削除し、listenCount: 0 を設定
        let firstMessageData: [String: Any] = [
            "senderID": message.senderID,
            "audioURL": message.audioURL,
            "duration": message.duration,
            "timestamp": FieldValue.serverTimestamp(),
            "listenCount": 0,
            "effectUsed": "アプローチ",
            "waveformSamples": []
        ]
        try await matchRef.collection("messages").addDocument(data: firstMessageData)
        
        print("🔥 DEBUG: マッチ承認完了＆チャットルーム作成済み")
        
        // UserMatchオブジェクトを作成して返す
        return UserMatch(
            id: matchID,
            user1ID: message.senderID,
            user2ID: message.receiverID,
            lastMessageDate: Date(),
            matchDate: Date()
        )
    }
}
