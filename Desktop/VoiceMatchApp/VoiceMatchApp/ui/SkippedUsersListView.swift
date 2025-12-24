import SwiftUI

struct SkippedUsersListView: View {
    @EnvironmentObject var userService: UserService
    @State private var skippedUsers: [UserProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if skippedUsers.isEmpty {
                Text("過去にスキップしたユーザーはいません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(skippedUsers) { user in
                    HStack {
                        UserAvatarView(imageURL: user.profileImageURL, size: 40)
                        
                        VStack(alignment: .leading) {
                            Text(user.username).font(.subheadline).bold()
                            if let age = user.profileItems["age"] {
                                Text("\(age)歳").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button("解除") {
                            Task {
                                await userService.unskipUser(targetUID: user.uid)
                                // リストから削除
                                withAnimation {
                                    skippedUsers.removeAll { $0.uid == user.uid }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("スキップしたユーザー")
        .onAppear { loadSkippedUsers() }
    }
    
    private func loadSkippedUsers() {
        guard let ids = userService.currentUserProfile?.skippedUserIDs else {
            isLoading = false
            return
        }
        
        // ★最新の10件を取得（配列の末尾が新しい想定）
        let last10IDs = Array(ids.suffix(10).reversed())
        
        Task {
            let users = await userService.fetchUsersByIDs(uids: last10IDs)
            await MainActor.run {
                self.skippedUsers = users
                self.isLoading = false
            }
        }
    }
}
