import SwiftUI
import PhotosUI // ★重要: 画像選択に必要

struct ProfileEditView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    // 基本情報
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var profileItems: [String: String] = [:]
    @State private var privacySettings: [String: Bool] = [:]
    
    // 画像選択用
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    
    // 録音画面用
    @State private var showVoiceRecorder = false
    
    var body: some View {
        NavigationView {
            Form {
                // セクション1: アイコンと名前
                Section(header: Text("アイコンと名前")) {
                    HStack {
                        Spacer()
                        VStack {
                            // 画像選択ボタン
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack {
                                    if let image = selectedImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else {
                                        UserAvatarView(imageURL: userService.currentUserProfile?.profileImageURL, size: 100)
                                    }
                                    
                                    // カメラアイコンのオーバーレイ
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Image(systemName: "camera.fill")
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(Color.brandPurple)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                    
                                    if isUploadingImage {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                            }
                            .onChange(of: selectedItem) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        selectedImage = uiImage
                                        isUploadingImage = true
                                        try? await userService.uploadProfileImage(image: uiImage)
                                        isUploadingImage = false
                                    }
                                }
                            }
                            
                            Text("タップして変更")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                    
                    TextField("名前", text: $username)
                }
                
                // セクション2: 自己紹介ボイス
                Section(header: Text("声のプロフィール")) {
                    Button(action: { showVoiceRecorder = true }) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.brandPurple)
                            Text("自己紹介ボイスを録音・設定する (最大30秒)")
                                .foregroundColor(.primary)
                            Spacer()
                            if userService.currentUserProfile?.bioAudioURL != nil {
                                Text("設定済み")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // セクション3: 自己紹介文
                Section(header: Text("自己紹介文")) {
                    ZStack(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("趣味や休日の過ごし方などを書いてみましょう")
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $bio)
                            .frame(minHeight: 100)
                    }
                }
                
                // セクション4: 詳細プロフィール (30項目)
                Section(header: Text("詳細プロフィール"), footer: Text("「非公開」にした項目は相手の詳細画面には表示されませんが、マッチングの共通点計算には使用されます。")) {
                    
                    ForEach(ProfileConstants.items, id: \.key) { item in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(item.displayName)
                                Spacer()
                                Menu {
                                    Button("未設定") {
                                        profileItems.removeValue(forKey: item.key)
                                    }
                                    ForEach(item.options, id: \.self) { option in
                                        Button(option) {
                                            profileItems[item.key] = option
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(profileItems[item.key] ?? "未設定")
                                            .foregroundColor(profileItems[item.key] == nil ? .gray : .primary)
                                            .multilineTextAlignment(.trailing)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            Toggle(isOn: Binding(
                                get: { privacySettings[item.key] ?? true },
                                set: { privacySettings[item.key] = $0 }
                            )) {
                                Text(privacySettings[item.key] ?? true ? "公開中" : "非公開")
                                    .font(.caption)
                                    .foregroundColor(privacySettings[item.key] ?? true ? .brandPurple : .secondary)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .brandPurple))
                        }
                        .padding(.vertical, 4)
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
                    .foregroundColor(.brandPurple)
                }
            }
            .onAppear {
                if let user = userService.currentUserProfile {
                    username = user.username
                    bio = user.bio
                    profileItems = user.profileItems
                    privacySettings = user.privacySettings
                }
            }
            .sheet(isPresented: $showVoiceRecorder) {
                VoiceBioRecordingView()
            }
        }
    }
    
    private func saveProfile() {
        guard var user = userService.currentUserProfile else { return }
        user.username = username
        user.bio = bio
        user.profileItems = profileItems
        user.privacySettings = privacySettings
        
        Task {
            try? await userService.updateUserProfile(profile: user)
            dismiss()
        }
    }
}
