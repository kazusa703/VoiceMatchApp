import SwiftUI

struct MessageListView: View {
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var userService: UserService
    
    // 重複を除去し、同じ人からのアプローチを1つにまとめる
    var uniqueApproaches: [Message] {
        let grouped = Dictionary(grouping: messageService.receivedApproaches, by: { $0.senderID })
        return grouped.values.compactMap { messages in
            messages.sorted(by: { $0.createdAt > $1.createdAt }).first
        }.sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // サブタブ切り替え (Enum使用)
                Picker("表示", selection: $messageService.selectedSection) {
                    Text("マッチ中").tag(MessageSection.matches)
                    Text("届いた").tag(MessageSection.received)
                    Text("送った").tag(MessageSection.sent)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // コンテンツの切り替え
                switch messageService.selectedSection {
                case .received:
                    if uniqueApproaches.isEmpty {
                        EmptyStateView(text: "まだアプローチは届いていません", icon: "tray")
                    } else {
                        List {
                            ForEach(uniqueApproaches) { message in
                                NavigationLink(destination: ApproachDetailView(message: message)) {
                                    ApproachRow(message: message)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    
                case .sent:
                    if messageService.sentApproaches.isEmpty {
                        EmptyStateView(text: "まだアプローチを送っていません", icon: "paperplane")
                    } else {
                        List {
                            ForEach(messageService.sentApproaches) { message in
                                SentApproachRow(message: message)
                            }
                        }
                        .listStyle(.plain)
                    }
                    
                case .matches:
                    if messageService.matches.isEmpty {
                        EmptyStateView(text: "まだマッチした相手がいません", icon: "person.2.slash")
                    } else {
                        List {
                            ForEach(messageService.matches) { match in
                                NavigationLink(destination: ChatDetailView(
                                    match: match,
                                    partnerName: "チャット"
                                )) {
                                    MessageMatchRow(match: match, currentUID: userService.currentUserProfile?.uid ?? "")
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                messageService.fetchReceivedApproaches()
                messageService.fetchSentApproaches()
                if let uid = userService.currentUserProfile?.uid {
                    Task { await messageService.fetchMatches(for: uid) }
                }
            }
        }
    }
}

// データがない時の表示
struct EmptyStateView: View {
    let text: String
    let icon: String
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text(text)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// アプローチ行
struct ApproachRow: View {
    let message: Message
    @State private var senderProfile: UserProfile?
    @EnvironmentObject var userService: UserService
    
    var body: some View {
        HStack {
            UserAvatarView(imageURL: senderProfile?.profileImageURL, size: 50)
            VStack(alignment: .leading) {
                Text(senderProfile?.username ?? "読み込み中...")
                    .font(.headline)
                Text("ボイスメッセージが届いています")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !message.isRead {
                Circle().fill(Color.brandPurple).frame(width: 10, height: 10)
            }
        }
        .task {
            try? senderProfile = await userService.fetchOtherUserProfile(uid: message.senderID)
        }
    }
}

// 送信済みアプローチ行
struct SentApproachRow: View {
    let message: Message
    @State private var receiverProfile: UserProfile?
    @EnvironmentObject var userService: UserService
    
    var body: some View {
        HStack {
            UserAvatarView(imageURL: receiverProfile?.profileImageURL, size: 50)
            VStack(alignment: .leading) {
                Text(receiverProfile?.username ?? "読み込み中...")
                    .font(.headline)
                Text("返信待ち...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(message.createdAt, style: .relative)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .task {
            try? receiverProfile = await userService.fetchOtherUserProfile(uid: message.receiverID)
        }
    }
}

// マッチ行
struct MessageMatchRow: View {
    let match: UserMatch
    let currentUID: String
    @State private var partnerProfile: UserProfile?
    @EnvironmentObject var userService: UserService
    
    var body: some View {
        HStack {
            UserAvatarView(imageURL: partnerProfile?.profileImageURL, size: 50)
            VStack(alignment: .leading) {
                Text(partnerProfile?.username ?? "読み込み中...")
                    .font(.headline)
                Text("タップしてチャットを開く")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .task {
            let partnerID = (match.user1ID == currentUID) ? match.user2ID : match.user1ID
            try? partnerProfile = await userService.fetchOtherUserProfile(uid: partnerID)
        }
    }
}
