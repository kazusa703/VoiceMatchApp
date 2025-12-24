import SwiftUI

struct MatchSettingsView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    // 編集用の一時データ
    @State private var editingUser: UserProfile
    
    // 初期化時に現在のユーザー情報をコピーする
    init(user: UserProfile) {
        _editingUser = State(initialValue: user)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本設定")) {
                    TextField("ユーザー名", text: $editingUser.username)
                    
                    // UserProfileに追加した maxMatchesPerCycle を表示
                    HStack {
                        Text("1日のマッチ上限")
                        Spacer()
                        Text("\(editingUser.maxMatchesPerCycle)人")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("プロフィール詳細")) {
                    Picker("居住地", selection: Binding(
                        get: { editingUser.profileItems["residence"] ?? "未設定" },
                        set: { editingUser.profileItems["residence"] = $0 }
                    )) {
                        Text("未設定").tag("未設定")
                        Text("東京都").tag("東京都")
                        Text("大阪府").tag("大阪府")
                        Text("北海道").tag("北海道")
                        Text("福岡県").tag("福岡県")
                    }
                    
                    TextField("職業", text: Binding(
                        get: { editingUser.profileItems["occupation"] ?? "" },
                        set: { editingUser.profileItems["occupation"] = $0 }
                    ))
                    
                    TextField("年齢", text: Binding(
                        get: { editingUser.profileItems["age"] ?? "" },
                        set: { editingUser.profileItems["age"] = $0 }
                    ))
                    .keyboardType(.numberPad)
                    
                    // 【修正】multipleChoiceItems を profileItems に変更
                    TextField("趣味（カンマ区切り）", text: Binding(
                        get: { editingUser.profileItems["hobbies"] ?? "" },
                        set: { editingUser.profileItems["hobbies"] = $0 }
                    ))
                    .placeholder(when: editingUser.profileItems["hobbies"]?.isEmpty ?? true) {
                        Text("例: サッカー, 映画, カフェ").foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveProfile()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func saveProfile() {
        Task {
            do {
                try await userService.updateUserProfile(profile: editingUser)
                dismiss()
            } catch {
                print("保存エラー: \(error)")
            }
        }
    }
}

// プレースホルダー用のExtension
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
