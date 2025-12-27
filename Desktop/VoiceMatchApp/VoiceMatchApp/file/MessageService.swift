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
        print("📨 [MessageService] fetchMatches開始: userID=\(userID)")
        
        do {
            let snapshot1 = try await db.collection("matches")
                .whereField("user1ID", isEqualTo: userID)
                .getDocuments()
            
            let snapshot2 = try await db.collection("matches")
                .whereField("user2ID", isEqualTo: userID)
                .getDocuments()
            
            print("📨 [MessageService] snapshot1: \(snapshot1.documents.count)件, snapshot2: \(snapshot2.documents.count)件")
            
            var allMatches: [UserMatch] = []
            allMatches.append(contentsOf: snapshot1.documents.compactMap { try? $0.data(as: UserMatch.self) })
            allMatches.append(contentsOf: snapshot2.documents.compactMap { try? $0.data(as: UserMatch.self) })
            
            self.matches = allMatches.sorted { $0.lastMessageDate > $1.lastMessageDate }
            print("📨 [MessageService] fetchMatches完了: \(self.matches.count)件のマッチ")
        } catch {
            print("❌ [MessageService] マッチ取得エラー: \(error)")
            print("❌ [MessageService] エラー詳細: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ボイスメッセージ送信
    
    func sendVoiceMessage(matchID: String, senderID: String, audioData: Data, duration: Double, effectUsed: String?) async throws {
        print("📨 [MessageService] sendVoiceMessage開始")
        print("📨 [MessageService] matchID: \(matchID)")
        print("📨 [MessageService] senderID: \(senderID)")
        print("📨 [MessageService] audioData size: \(audioData.count) bytes")
        print("📨 [MessageService] duration: \(duration)秒")
        print("📨 [MessageService] effectUsed: \(effectUsed ?? "なし")")
        
        // 1分以内かチェック
        guard duration <= 60 else {
            print("❌ [MessageService] 60秒を超えています")
            throw MessageError.durationTooLong
        }
        
        // audioDataが空でないか確認
        guard audioData.count > 0 else {
            print("❌ [MessageService] audioDataが空です")
            throw MessageError.emptyAudioData
        }
        
        // 音声をStorageにアップロード
        let fileName = "\(UUID().uuidString).m4a"
        let ref = storage.reference().child("chat_voices/\(matchID)/\(fileName)")
        print("📨 [MessageService] Storageパス: chat_voices/\(matchID)/\(fileName)")
        
        do {
            print("📨 [MessageService] Storageへのアップロード開始...")
            _ = try await ref.putDataAsync(audioData)
            print("✅ [MessageService] Storageへのアップロード完了")
            
            let url = try await ref.downloadURL()
            print("✅ [MessageService] ダウンロードURL取得: \(url.absoluteString)")
            
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
            print("📨 [MessageService] Firestoreへの保存開始: \(messageRef.path)")
            
            try messageRef.setData(from: message)
            print("✅ [MessageService] Firestoreへの保存完了")
            
            // lastMessageDate更新
            try await db.collection("matches").document(matchID).updateData([
                "lastMessageDate": Date()
            ])
            print("✅ [MessageService] lastMessageDate更新完了")
            
            print("✅ [MessageService] sendVoiceMessage完了")
            
        } catch {
            print("❌ [MessageService] sendVoiceMessageエラー: \(error)")
            print("❌ [MessageService] エラー詳細: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [MessageService] NSError domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ [MessageService] NSError userInfo: \(nsError.userInfo)")
            }
            throw error
        }
    }
    
    // MARK: - メッセージ購読
    
    func listenToMessages(for matchID: String) {
        print("📨 [MessageService] listenToMessages開始: matchID=\(matchID)")
        
        messagesListener?.remove()
        
        let messagesPath = "matches/\(matchID)/messages"
        print("📨 [MessageService] 購読パス: \(messagesPath)")
        
        messagesListener = db.collection("matches").document(matchID)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [MessageService] メッセージ購読エラー: \(error)")
                    print("❌ [MessageService] エラー詳細: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [MessageService] documentsがnil")
                    return
                }
                
                print("📨 [MessageService] メッセージ受信: \(documents.count)件")
                
                let messages = documents.compactMap { doc -> VoiceMessage? in
                    do {
                        let message = try doc.data(as: VoiceMessage.self)
                        print("📨 [MessageService] メッセージパース成功: id=\(message.id ?? "nil"), senderID=\(message.senderID)")
                        return message
                    } catch {
                        print("❌ [MessageService] メッセージパースエラー: \(error)")
                        print("❌ [MessageService] ドキュメントデータ: \(doc.data())")
                        return nil
                    }
                }
                
                self?.currentMessages = messages
                print("📨 [MessageService] currentMessages更新: \(messages.count)件")
            }
    }
    
    func clearMessages() {
        print("📨 [MessageService] clearMessages")
        messagesListener?.remove()
        messagesListener = nil
        currentMessages = []
    }
    
    // MARK: - 既読処理
    
    func markAsRead(matchID: String, messageID: String) async {
        print("📨 [MessageService] markAsRead: matchID=\(matchID), messageID=\(messageID)")
        try? await db.collection("matches").document(matchID)
            .collection("messages").document(messageID)
            .updateData(["isRead": true])
    }
}

// MARK: - エラー定義

enum MessageError: LocalizedError {
    case durationTooLong
    case emptyAudioData
    
    var errorDescription: String? {
        switch self {
        case .durationTooLong:
            return "ボイスメッセージは1分以内にしてください"
        case .emptyAudioData:
            return "音声データが空です"
        }
    }
}
