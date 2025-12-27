import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    
    @State private var editingUser: UserProfile
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var showVoiceRecorder = false
    @State private var selectedVoiceItem: VoiceProfileItem?
    
    init(user: UserProfile) {
        _editingUser = State(initialValue: user)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    // 1. アイコン画像
                    Section(header: Text("アイコン")) {
                        VStack(spacing: 15) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    UserAvatarView(imageURL: editingUser.iconImageURL, size: 100)
                                    
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.brandPurple)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                            }
                            .onChange(of: selectedItem) { _ in uploadIcon() }
                            
                            Text("タップして変更")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    
                    // 2. ユーザー名
                    Section(header: Text("ユーザー名")) {
                        TextField("ユーザー名", text: $editingUser.username)
                    }
                    
                    // 3. ボイスプロフィール
                    Section(header: Text("ボイスプロフィール")) {
                        ForEach(VoiceProfileConstants.items) { item in
                            VoiceProfileRow(
                                item: item,
                                voiceData: editingUser.voiceProfiles[item.key],
                                onRecord: {
                                    selectedVoiceItem = item
                                    showVoiceRecorder = true
                                },
                                onDelete: {
                                    Task {
                                        try? await userService.deleteVoiceProfile(key: item.key)
                                        editingUser.voiceProfiles.removeValue(forKey: item.key)
                                    }
                                }
                            )
                        }
                        
                        if editingUser.voiceProfiles["naturalVoice"] == nil {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("地声は必須です。設定するまで他のユーザーに表示されません。")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    // 4. 選択式プロフィール
                    Section(header: Text("基本情報")) {
                        ForEach(ProfileConstants.selectionItems, id: \.key) { itemDef in
                            SelectionProfileRow(
                                itemDef: itemDef,
                                selectedValue: Binding(
                                    get: { editingUser.profileItems[itemDef.key] ?? "未設定" },
                                    set: { editingUser.profileItems[itemDef.key] = $0 }
                                ),
                                isPublic: Binding(
                                    get: { editingUser.profileItemsVisibility[itemDef.key] ?? false },
                                    set: { editingUser.profileItemsVisibility[itemDef.key] = $0 }
                                )
                            )
                        }
                    }
                    
                    // 5. 自由入力プロフィール
                    Section(header: Text("趣味・好み")) {
                        Text("複数入力できます。入力後にEnterまたは追加ボタンを押してください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(ProfileConstants.freeInputItems, id: \.key) { itemDef in
                            FreeInputProfileRow(
                                itemDef: itemDef,
                                values: Binding(
                                    get: { editingUser.profileFreeItems[itemDef.key] ?? [] },
                                    set: { editingUser.profileFreeItems[itemDef.key] = $0 }
                                ),
                                isPublic: Binding(
                                    get: { editingUser.profileItemsVisibility[itemDef.key] ?? false },
                                    set: { editingUser.profileItemsVisibility[itemDef.key] = $0 }
                                )
                            )
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
                if let item = selectedVoiceItem {
                    ProfileVoiceRecordingView(
                        voiceItem: item,
                        isPro: purchaseManager.isPro,
                        onSave: { audioURL, duration, effectUsed in
                            Task {
                                try? await userService.uploadVoiceProfile(
                                    key: item.key,
                                    audioURL: audioURL,
                                    duration: duration,
                                    effectUsed: effectUsed
                                )
                                editingUser.voiceProfiles[item.key] = VoiceProfileData(
                                    audioURL: audioURL.absoluteString,
                                    duration: duration,
                                    effectUsed: effectUsed
                                )
                            }
                        }
                    )
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
    
    private func uploadIcon() {
        guard let selectedItem = selectedItem else { return }
        isUploading = true
        
        Task {
            if let data = try? await selectedItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                do {
                    try await userService.uploadIconImage(image: image)
                    if let updatedURL = userService.currentUserProfile?.iconImageURL {
                        editingUser.iconImageURL = updatedURL
                    }
                } catch {
                    print("アイコンアップロードエラー: \(error)")
                }
            }
            isUploading = false
        }
    }
}

// MARK: - 選択式プロフィール行

struct SelectionProfileRow: View {
    let itemDef: ProfileItemDefinition
    @Binding var selectedValue: String
    @Binding var isPublic: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(itemDef.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("", selection: $selectedValue) {
                    Text("未設定").tag("未設定")
                    ForEach(itemDef.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            // 公開/非公開トグル
            HStack {
                Spacer()
                Toggle(isOn: $isPublic) {
                    EmptyView()
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
                
                Text(isPublic ? "公開" : "非公開")
                    .font(.caption)
                    .foregroundColor(isPublic ? .green : .gray)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 自由入力プロフィール行

struct FreeInputProfileRow: View {
    let itemDef: ProfileItemDefinition
    @Binding var values: [String]
    @Binding var isPublic: Bool
    
    @State private var inputText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー
            HStack {
                Text(itemDef.displayName)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle(isOn: $isPublic) {
                    EmptyView()
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
                
                Text(isPublic ? "公開" : "非公開")
                    .font(.caption)
                    .foregroundColor(isPublic ? .green : .gray)
                    .frame(width: 50)
            }
            
            // 入力済みタグ
            if !values.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(values, id: \.self) { value in
                        TagView(text: value) {
                            values.removeAll { $0 == value }
                        }
                    }
                }
            }
            
            // 入力欄
            if values.count < itemDef.maxInputCount {
                HStack {
                    TextField(itemDef.placeholder, text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addValue()
                        }
                    
                    Button(action: addValue) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.brandPurple)
                            .font(.title2)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Text("最大\(itemDef.maxInputCount)件まで")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func addValue() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !values.contains(trimmed) && values.count < itemDef.maxInputCount {
            values.append(trimmed)
            inputText = ""
        }
    }
}

// MARK: - タグビュー

struct TagView: View {
    let text: String
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundColor(.brandPurple)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.brandPurple.opacity(0.1))
        .cornerRadius(15)
    }
}

// MARK: - フローレイアウト（タグを折り返し表示）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - ボイスプロフィール行

struct VoiceProfileRow: View {
    let item: VoiceProfileItem
    let voiceData: VoiceProfileData?
    var onRecord: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.displayName)
                        .fontWeight(.medium)
                    
                    if item.isRequired {
                        Text("必須")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    if !item.allowsEffect {
                        Text("エフェクト不可")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                if let voice = voiceData {
                    Text(String(format: "%.1f秒", voice.duration))
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("未設定")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if voiceData != nil {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 8)
            }
            
            Button(action: onRecord) {
                Text(voiceData == nil ? "録音" : "再録音")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandPurple)
                    .cornerRadius(15)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ボイス録音画面

struct ProfileVoiceRecordingView: View {
    let voiceItem: VoiceProfileItem
    let isPro: Bool
    var onSave: (URL, Double, String?) -> Void
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var effectManager = VoiceEffectManager.shared
    
    @State private var recordingDuration: Double = 0
    @State private var timer: Timer?
    @State private var isProcessing = false
    @State private var processedURL: URL?
    @State private var showEffectSettings = false
    @State private var hasRecording = false
    @State private var selectedEffect: VoiceEffectDefinition?
    
    var availableEffects: [VoiceEffectDefinition] {
        VoiceEffectConstants.getEffectsForUser(isPro: isPro)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(voiceItem.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !voiceItem.allowsEffect {
                        Text("地声はエフェクトを使用できません")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Text("最大60秒 / 最小\(Int(voiceItem.minDuration))秒")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                Spacer()
                
                Text(String(format: "%.1f秒", recordingDuration))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(recordingDuration >= voiceItem.minDuration ? .primary : .red)
                
                if audioRecorder.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("録音中...")
                            .foregroundColor(.red)
                    }
                }
                
                Button(action: toggleRecording) {
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.red : Color.brandPurple)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                        .shadow(radius: audioRecorder.isRecording ? 10 : 0)
                }
                
                Spacer()
                
                if voiceItem.allowsEffect && hasRecording && !audioRecorder.isRecording {
                    VStack(spacing: 12) {
                        Text("エフェクト")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableEffects) { effect in
                                    EffectButton(
                                        effect: effect,
                                        isSelected: selectedEffect?.key == effect.key,
                                        onSelect: { selectEffect(effect) }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        if isPro && selectedEffect != nil {
                            Button("詳細調整") {
                                showEffectSettings = true
                            }
                            .font(.caption)
                            .foregroundColor(.brandPurple)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
                
                if hasRecording && !audioRecorder.isRecording {
                    HStack(spacing: 20) {
                        Button(action: resetRecording) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                Text("撮り直す")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: previewAudio) {
                            VStack {
                                Image(systemName: audioPlayer.isPlaying ? "stop.circle" : "play.circle")
                                    .font(.title2)
                                Text(audioPlayer.isPlaying ? "停止" : "試聴")
                                    .font(.caption)
                            }
                            .foregroundColor(.brandPurple)
                        }
                        
                        Spacer()
                        
                        Button(action: saveVoice) {
                            if isProcessing {
                                ProgressView()
                            } else {
                                VStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                    Text("保存")
                                        .font(.caption)
                                }
                                .foregroundColor(.green)
                            }
                        }
                        .disabled(recordingDuration < voiceItem.minDuration || isProcessing)
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        cleanup()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEffectSettings) {
                EffectSettingsView(effectManager: effectManager)
            }
            .onAppear {
                selectedEffect = voiceItem.allowsEffect ? VoiceEffectConstants.freeEffects.first : nil
            }
            .onDisappear {
                cleanup()
            }
        }
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        audioPlayer.stopPlayback()
        recordingDuration = 0
        processedURL = nil
        hasRecording = false
        
        audioRecorder.startRecording()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if audioRecorder.isRecording {
                recordingDuration += 0.1
                if recordingDuration >= voiceItem.maxDuration {
                    stopRecording()
                }
            }
        }
    }
    
    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        audioRecorder.stopRecording()
        hasRecording = audioRecorder.recordingURL != nil
    }
    
    private func resetRecording() {
        audioPlayer.stopPlayback()
        audioRecorder.resetRecording()
        recordingDuration = 0
        processedURL = nil
        hasRecording = false
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        audioPlayer.stopPlayback()
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        }
    }
    
    private func selectEffect(_ effect: VoiceEffectDefinition) {
        selectedEffect = effect
        effectManager.selectEffect(effect)
        processedURL = nil
    }
    
    private func previewAudio() {
        if audioPlayer.isPlaying {
            audioPlayer.stopPlayback()
            return
        }
        
        guard let recordedURL = audioRecorder.recordingURL else { return }
        
        if voiceItem.allowsEffect, let effect = selectedEffect, effect.key != "normal" {
            if let processed = processedURL {
                audioPlayer.startPlayback(url: processed)
            } else {
                isProcessing = true
                effectManager.applyEffect(to: recordedURL) { result in
                    isProcessing = false
                    switch result {
                    case .success(let url):
                        processedURL = url
                        audioPlayer.startPlayback(url: url)
                    case .failure:
                        audioPlayer.startPlayback(url: recordedURL)
                    }
                }
            }
        } else {
            audioPlayer.startPlayback(url: recordedURL)
        }
    }
    
    private func saveVoice() {
        guard recordingDuration >= voiceItem.minDuration else { return }
        guard let recordedURL = audioRecorder.recordingURL else { return }
        
        let effectKey = voiceItem.allowsEffect ? selectedEffect?.key : nil
        
        if voiceItem.allowsEffect, let effect = selectedEffect, effect.key != "normal" {
            if let processed = processedURL {
                onSave(processed, recordingDuration, effectKey)
                dismiss()
            } else {
                isProcessing = true
                effectManager.applyEffect(to: recordedURL) { result in
                    isProcessing = false
                    switch result {
                    case .success(let url):
                        onSave(url, recordingDuration, effectKey)
                        dismiss()
                    case .failure:
                        onSave(recordedURL, recordingDuration, nil)
                        dismiss()
                    }
                }
            }
        } else {
            onSave(recordedURL, recordingDuration, nil)
            dismiss()
        }
    }
}

// MARK: - エフェクトボタン

struct EffectButton: View {
    let effect: VoiceEffectDefinition
    let isSelected: Bool
    var onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(systemName: effect.icon)
                    .font(.title2)
                Text(effect.displayName)
                    .font(.caption)
            }
            .frame(width: 70, height: 70)
            .foregroundColor(isSelected ? .white : .brandPurple)
            .background(isSelected ? Color.brandPurple : Color.brandPurple.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandPurple, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

// MARK: - エフェクト詳細設定

struct EffectSettingsView: View {
    @ObservedObject var effectManager: VoiceEffectManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ピッチ")) {
                    HStack {
                        Text("低い")
                        Slider(value: Binding(
                            get: { Double(effectManager.currentSettings.pitch) },
                            set: { effectManager.updatePitch(Float($0)) }
                        ), in: -2400...2400)
                        Text("高い")
                    }
                }
                
                Section(header: Text("スピード")) {
                    HStack {
                        Text("遅い")
                        Slider(value: Binding(
                            get: { Double(effectManager.currentSettings.rate) },
                            set: { effectManager.updateRate(Float($0)) }
                        ), in: 0.5...2.0)
                        Text("速い")
                    }
                }
                
                Section(header: Text("リバーブ")) {
                    HStack {
                        Text("なし")
                        Slider(value: Binding(
                            get: { Double(effectManager.currentSettings.reverb) },
                            set: { effectManager.updateReverb(Float($0)) }
                        ), in: 0...100)
                        Text("強い")
                    }
                }
                
                Section(header: Text("歪み")) {
                    HStack {
                        Text("なし")
                        Slider(value: Binding(
                            get: { Double(effectManager.currentSettings.distortion) },
                            set: { effectManager.updateDistortion(Float($0)) }
                        ), in: 0...100)
                        Text("強い")
                    }
                }
            }
            .navigationTitle("エフェクト調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }
}
