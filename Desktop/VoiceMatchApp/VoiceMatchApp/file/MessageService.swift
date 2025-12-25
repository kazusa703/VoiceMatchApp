import Foundation
import FirebaseFirestore
import FirebaseStorage
import Combine
import FirebaseAuth

// メッセージセクションの列挙型
enum MessageSection {
    case matches
    case received
    case sent
}

class MessageService: ObservableObject {
    @Published var matches: [UserMatch] = []
    @Published var currentMessages: [VoiceMessage] = []
    @Published var receivedApproaches: [Message] = []
    @Published var sentApproaches: [Message] = []
    @Published var selectedSection: MessageSection = .matches
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var messagesListener: ListenerRegistration?
    private var currentMatchID: String?

    // MARK: - チャット機能
    
    func listenToMessages(for matchID: String) {
        if currentMatchID == matchID { return }
        
        messagesListener?.remove()
        currentMatchID = matchID
        self.currentMessages = []
        
        messagesListener = db.collection("matches").document(matchID).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    self.currentMessages = documents.compactMap { try? $0.data(as: VoiceMessage.self) }
                }
            }
    }
    
    func clearMessages() {
        messagesListener?.remove()
        messagesListener = nil
        currentMatchID = nil
        currentMessages = []
    }
    
    func incrementListenCount(messageID: String, matchID: String) {
        let docRef = db.collection("matches").document(matchID).collection("messages").document(messageID)
        db.runTransaction({ (transaction, _ ) -> Any? in
            let _ = try? transaction.getDocument(docRef)
            transaction.updateData(["listenCount": FieldValue.increment(Int64(1))], forDocument: docRef)
            return nil
        }) { _, _ in }
    }

    // MARK: - マッチ一覧取得
    
    func fetchMatches(for uid: String, blockedUserIDs: [String] = []) async {
        do {
            let q1 = db.collection("matches").whereField("user1ID", isEqualTo: uid)
            let q2 = db.collection("matches").whereField("user2ID", isEqualTo: uid)
            
            let (s1, s2) = try await (q1.getDocuments(), q2.getDocuments())
            let m1 = s1.documents.compactMap { try? $0.data(as: UserMatch.self) }
            let m2 = s2.documents.compactMap { try? $0.data(as: UserMatch.self) }
            
            let all = (m1 + m2).sorted(by: { $0.lastMessageDate > $1.lastMessageDate })
            
            await MainActor.run {
                self.matches = all.filter { match in
                    let partnerID = match.user1ID == uid ? match.user2ID : match.user1ID
                    return !blockedUserIDs.contains(partnerID)
                }
            }
        } catch { print("FetchMatches Error: \(error)") }
    }
    
    // MARK: - チャット送信
    
    func sendVoiceMessage(senderID: String, receiverID: String, audioData: Data, duration: Double, effectName: String?, waveformSamples: [Float]) async throws {
        let matchID = [senderID, receiverID].sorted().joined(separator: "_")
        let fileName = "\(UUID().uuidString).m4a"
        let ref = storage.reference().child("voices/\(matchID)/\(fileName)")
        
        let metadata = StorageMetadata(); metadata.contentType = "audio/m4a"
        let _ = try await ref.putDataAsync(audioData, metadata: metadata)
        let url = try await ref.downloadURL()
        
        let msg: [String: Any] = [
            "senderID": senderID,
            "audioURL": url.absoluteString,
            "duration": duration,
            "timestamp": FieldValue.serverTimestamp(),
            "listenCount": 0,
            "effectUsed": effectName ?? "Normal",
            "waveformSamples": waveformSamples
        ]
        
        let matchRef = db.collection("matches").document(matchID)
        try await matchRef.setData([
            "user1ID": senderID,
            "user2ID": receiverID,
            "lastMessageDate": FieldValue.serverTimestamp()
        ], merge: true)
        
        try await matchRef.collection("messages").addDocument(data: msg)
    }

    // MARK: - アプローチ送信
    
    func sendApproachVoiceMessage(to receiverID: String, audioURL: URL, duration: TimeInterval, userService: UserService) async throws {
        guard userService.canSendApproach() else {
            throw NSError(domain: "App", code: 403, userInfo: [NSLocalizedDescriptionKey: "本日の送信上限に達しました"])
        }
        
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        
        // 既にマッチ済みか確認
        let matchID = [currentUID, receiverID].sorted().joined(separator: "_")
        let matchDoc = try await db.collection("matches").document(matchID).getDocument()
        
        if matchDoc.exists {
            let data = try Data(contentsOf: audioURL)
            try await sendVoiceMessage(senderID: currentUID, receiverID: receiverID, audioData: data, duration: duration, effectName: "再アプローチ", waveformSamples: [])
            return
        }
        
        // 通常アプローチ
        let filename = "approaches/\(UUID().uuidString).m4a"
        let ref = storage.reference().child(filename)
        let data = try Data(contentsOf: audioURL)
        let _ = try await ref.putDataAsync(data, metadata: nil)
        let url = try await ref.downloadURL()
        
        let approachData: [String: Any] = [
            "senderID": currentUID,
            "receiverID": receiverID,
            "audioURL": url.absoluteString,
            "duration": duration,
            "createdAt": FieldValue.serverTimestamp(),
            "isRead": false,
            "isMatched": false
        ]
        try await db.collection("messages").addDocument(data: approachData)
        try await userService.incrementApproachCount()
    }
    
    // MARK: - アプローチ承認・拒否
    
    /// アプローチを承認してマッチを作成
    func acceptApproach(message: Message) async throws -> UserMatch? {
        guard let messageID = message.id else { return nil }
        guard let currentUID = Auth.auth().currentUser?.uid else { return nil }
        
        // メッセージをマッチ済みに更新
        try await db.collection("messages").document(messageID).updateData(["isMatched": true])
        
        // マッチを作成
        let matchID = [message.senderID, currentUID].sorted().joined(separator: "_")
        let matchData: [String: Any] = [
            "user1ID": message.senderID,
            "user2ID": currentUID,
            "matchDate": FieldValue.serverTimestamp(),
            "lastMessageDate": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("matches").document(matchID).setData(matchData)
        
        // UserMatchを返す
        let match = UserMatch(
            id: matchID,
            user1ID: message.senderID,
            user2ID: currentUID,
            lastMessageDate: Date(),
            matchDate: Date()
        )
        
        return match
    }
    
    /// アプローチを拒否（削除）
    func declineApproach(message: Message) async {
        guard let messageID = message.id else { return }
        try? await db.collection("messages").document(messageID).delete()
    }
    
    // MARK: - 受信/送信アプローチの取得
    
    func fetchReceivedApproaches() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("messages")
            .whereField("receiverID", isEqualTo: uid)
            .whereField("isMatched", isEqualTo: false)
            .addSnapshotListener { s, _ in
                guard let docs = s?.documents else { return }
                self.receivedApproaches = docs.compactMap { try? $0.data(as: Message.self) }
            }
    }
    
    func fetchSentApproaches() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("messages")
            .whereField("senderID", isEqualTo: uid)
            .whereField("isMatched", isEqualTo: false)
            .addSnapshotListener { s, _ in
                guard let docs = s?.documents else { return }
                self.sentApproaches = docs.compactMap { try? $0.data(as: Message.self) }
            }
    }
}
