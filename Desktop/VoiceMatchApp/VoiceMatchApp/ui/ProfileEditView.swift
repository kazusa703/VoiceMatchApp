import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    // 編集用の一時データ
    @State private var editingUser: UserProfile
    
    // 画像選択用
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    
    // ボイス録音画面の表示管理
    @State private var showVoiceRecorder = false
    
    init(user: UserProfile) {
        _editingUser = State(initialValue: user)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    // 1. アイコンと名前
                    Section(header: Text("アイコンと名前")) {
                        VStack(spacing: 15) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    UserAvatarView(imageURL: editingUser.profileImageURL, size: 100)
                                    
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.brandPurple)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                            .onChange(of: selectedItem) { _ in uploadImage() }
                            
                            Text("タップして変更")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("ユーザー名", text: $editingUser.username)
                                .multilineTextAlignment(.center)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    
                    // 2. 声のプロフィール
                    Section(header: Text("声のプロフィール")) {
                        Button(action: { showVoiceRecorder = true }) {
                            HStack {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.brandPurple)
                                Text("自己紹介ボイスを録音・設定する (最大30秒)")
                                Spacer()
                                if editingUser.bioAudioURL != nil {
                                    Text("設定済み")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    // 3. 自己紹介文
                    Section(header: Text("自己紹介文")) {
                        TextEditor(text: Binding(
                            get: { editingUser.bio },
                            set: { editingUser.bio = $0 }
                        ))
                            .frame(height: 100)
                            .overlay(
                                Group {
                                    if editingUser.bio.isEmpty {
                                        Text("趣味や休日の過ごし方などを書いてみましょう")
                                            .foregroundColor(.gray.opacity(0.5))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 8)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    
                    // 4. 詳細プロフィール
                    Section(header: Text("詳細プロフィール")) {
                        ForEach(ProfileConstants.items, id: \.key) { itemDef in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(itemDef.displayName)
                                    Spacer()
                                    
                                    Picker("", selection: Binding(
                                        get: { editingUser.profileItems[itemDef.key] ?? "未設定" },
                                        set: { editingUser.profileItems[itemDef.key] = $0 }
                                    )) {
                                        Text("未設定").tag("未設定")
                                        ForEach(itemDef.options, id: \.self) { option in
                                            Text(option).tag(option)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                }
                                
                                // 公開・非公開のトグルスイッチ
                                HStack {
                                    Text("公開中")
                                        .font(.caption2)
                                        .foregroundColor(editingUser.privacySettings[itemDef.key] ?? true ? .brandPurple : .secondary)
                                    
                                    Toggle("", isOn: Binding(
                                        get: { editingUser.privacySettings[itemDef.key] ?? true },
                                        set: { editingUser.privacySettings[itemDef.key] = $0 }
                                    ))
                                    .labelsHidden()
                                    .scaleEffect(0.8)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if isUploading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("アップロード中...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("プロフィール編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveProfile() }
                        .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showVoiceRecorder) {
                VoiceBioRecordingView()
            }
        }
    }
    
    // MARK: - ロジック
    
    private func saveProfile() {
        Task {
            do {
                try await userService.updateUserProfile(profile: editingUser)
                dismiss()
            } catch {
                print("プロフィール保存エラー: \(error)")
            }
        }
    }
    
    private func uploadImage() {
        guard let selectedItem = selectedItem else { return }
        isUploading = true
        
        Task {
            if let data = try? await selectedItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                do {
                    try await userService.uploadProfileImage(image: image)
                    try? await userService.fetchOrCreateUserProfile(uid: editingUser.uid)
                    if let updatedURL = userService.currentUserProfile?.profileImageURL {
                        await MainActor.run {
                            editingUser.profileImageURL = updatedURL
                            isUploading = false
                        }
                    }
                } catch {
                    print("画像アップロードエラー: \(error)")
                    await MainActor.run { isUploading = false }
                }
            }
        }
    }
}
