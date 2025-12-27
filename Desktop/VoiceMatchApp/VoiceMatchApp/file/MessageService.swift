import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

enum MessageSection: String, CaseIterable {
    case matches = "matches"
    case received = "received"
}

@MainActor
class MessageService: ObservableObject {
    @Published var selectedSection: MessageSection = .matches
    @Published var matches: [UserMatch] = []
    @Published var currentMessages: [VoiceMessage] = []
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var messagesListener: ListenerRegistration?
    
    // MARK: - マッチ一覧取得
    
    func fetchMatches(for userID: String) async {
        do {
            let snapshot1 = try await db.collection("matches")
                .whereField("user1ID", isEqualTo: userID)
                .getDocuments()
            
            let snapshot2 = try await db.collection("matches")
                .whereField("user2ID", isEqualTo: userID)
                .getDocuments()
            
            var allMatches: [UserMatch] = []
            allMatches.append(contentsOf: snapshot1.documents.compactMap { try? $0.data(as: UserMatch.self) })
            allMatches.append(contentsOf: snapshot2.documents.compactMap { try? $0.data(as: UserMatch.self) })
            
            self.matches = allMatches.sorted { $0.lastMessageDate > $1.lastMessageDate }
        } catch {
            print("マッチ取得エラー: \(error)")
        }
    }
    
    // MARK: - ボイスメッセージ送信
    
    func sendVoiceMessage(matchID: String, senderID: String, audioData: Data, duration: Double, effectUsed: String?) async throws {
        // 1分以内かチェック
        guard duration <= 60 else {
            throw MessageError.durationTooLong
        }
        
        // 音声をStorageにアップロード
        let fileName = "\(UUID().uuidString).m4a"
        let ref = storage.reference().child("chat_voices/\(matchID)/\(fileName)")
        _ = try await ref.putDataAsync(audioData)
        let url = try await ref.downloadURL()
        
        // Firestoreに保存
        let message = VoiceMessage(
            senderID: senderID,
            audioURL: url.absoluteString,
            duration: duration,
            timestamp: Date(),
            isRead: false,
            effectUsed: effectUsed
        )
        
        let messageRef = db.collection("matches").document(matchID).collection("messages").document()
        try messageRef.setData(from: message)
        
        // lastMessageDate更新
        try await db.collection("matches").document(matchID).updateData([
            "lastMessageDate": Date()
        ])
    }
    
    // MARK: - メッセージ購読
    
    func listenToMessages(for matchID: String) {
        messagesListener?.remove()
        
        messagesListener = db.collection("matches").document(matchID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }
                self?.currentMessages = documents.compactMap { try? $0.data(as: VoiceMessage.self) }
            }
    }
    
    func clearMessages() {
        messagesListener?.remove()
        messagesListener = nil
        currentMessages = []
    }
    
    // MARK: - 既読処理
    
    func markAsRead(matchID: String, messageID: String) async {
        try? await db.collection("matches").document(matchID)
            .collection("messages").document(messageID)
            .updateData(["isRead": true])
    }
}

// MARK: - エラー定義

enum MessageError: LocalizedError {
    case durationTooLong
    
    var errorDescription: String? {
        switch self {
        case .durationTooLong:
            return "ボイスメッセージは1分以内にしてください"
        }
    }
}
