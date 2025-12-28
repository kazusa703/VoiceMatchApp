import SwiftUI

struct FilterView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @Binding var filterConditions: [String: String]
    @Binding var minCommonPoints: Int
    @Binding var commonPointsMode: String
    @Binding var maxDistance: Double
    
    // ハッシュタグフィルター
    @State private var hashtagFilter: [String] = []
    @State private var hashtagInput: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var showSuggestions = false
    
    // フィルタリングされたサジェスト
    private var filteredSuggestions: [String] {
        if hashtagInput.isEmpty {
            return []
        }
        
        let normalizedInput = hashtagInput
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "#", with: "")
            .lowercased()
        
        return userService.hashtagSuggestions.filter { suggestion in
            // すでに選択済みは除外
            guard !hashtagFilter.contains(suggestion) else { return false }
            
            let normalizedSuggestion = suggestion
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "　", with: "")
                .lowercased()
            
            return normalizedSuggestion.contains(normalizedInput) ||
                   suggestion.lowercased().contains(hashtagInput.lowercased())
        }.prefix(8).map { $0 }
    }
    
    // MARK: - Computed Properties
    
    // 現在の条件でのヒット数を計算（いいね済みを除外）
    private var filteredHitCount: Int {
        var users = userService.discoveryUsers
        
        // 1. いいね済みユーザーを除外
        let likedUserIDs = userService.currentUserProfile?.likedUserIDs ?? []
        users = users.filter { !likedUserIDs.contains($0.uid) }
        
        // 2. 選択式フィルター（AND検索）
        for (key, value) in filterConditions {
            if !value.isEmpty && value != "指定なし" {
                users = users.filter { $0.profileItems[key] == value }
            }
        }
        
        // 3. ハッシュタグフィルター（AND検索）
        if !hashtagFilter.isEmpty {
            users = users.filter { user in
                hashtagFilter.allSatisfy { filterTag in
                    let normalizedFilter = filterTag
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "　", with: "")
                        .lowercased()
                    
                    return user.hashtags.contains { userTag in
                        let normalizedUserTag = userTag
                            .replacingOccurrences(of: " ", with: "")
                            .replacingOccurrences(of: "　", with: "")
                            .lowercased()
                        return normalizedUserTag.contains(normalizedFilter)
                    }
                }
            }
        }
        
        // 4. 共通点フィルター
        let currentMinPoints: Int
        switch commonPointsMode {
        case "1+": currentMinPoints = 1
        case "3+": currentMinPoints = 3
        case "5+": currentMinPoints = 5
        default: currentMinPoints = 0
        }
        
        if currentMinPoints > 0 {
            users = users.filter { user in
                userService.calculateCommonPoints(with: user) >= currentMinPoints
            }
        }
        
        return users.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヒット数表示
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.brandPurple)
                    Text("\(filteredHitCount)人がヒット")
                        .font(.headline)
                        .foregroundColor(.brandPurple)
                    Text("（いいね済み除外）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.brandPurple.opacity(0.1))
                
                Form {
                    // 選択式フィルター
                    Section(header: Text("基本条件")) {
                        ForEach(ProfileConstants.selectionItems, id: \.key) { itemDef in
                            HStack {
                                Text(itemDef.displayName)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { filterConditions[itemDef.key] ?? "指定なし" },
                                    set: { filterConditions[itemDef.key] = $0 == "指定なし" ? nil : $0 }
                                )) {
                                    Text("指定なし").tag("指定なし")
                                    ForEach(itemDef.options, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                    }
                    
                    // ハッシュタグフィルター
                    Section(header: Text("ハッシュタグ")) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 確定済みタグ
                            if !hashtagFilter.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(hashtagFilter, id: \.self) { tag in
                                        FilterConfirmedChip(text: tag) {
                                            hashtagFilter.removeAll { $0 == tag }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // 入力欄（FlowLayoutの外）
                            HStack(spacing: 8) {
                                Text("#")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandPurple)
                                
                                TextField("タグを入力（例: 映画）", text: $hashtagInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($isInputFocused)
                                    .onSubmit {
                                        addHashtagFilter()
                                    }
                                
                                Button(action: addHashtagFilter) {
                                    Text("確定")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(hashtagInput.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.green)
                                        .cornerRadius(10)
                                }
                                .disabled(hashtagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            
                            // サジェストリスト
                            if showSuggestions && isInputFocused && !filteredSuggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("他のユーザーが使っているタグ")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 8)
                                    
                                    ForEach(filteredSuggestions, id: \.self) { suggestion in
                                        Button(action: {
                                            addSuggestion(suggestion)
                                        }) {
                                            HStack {
                                                highlightedText(suggestion: suggestion, input: hashtagInput)
                                                Spacer()
                                                Text("タップで追加")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color.white)
                                        }
                                        
                                        if suggestion != filteredSuggestions.last {
                                            Divider()
                                        }
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            // ヒント
                            if hashtagInput.isEmpty {
                                Text("入力したタグをすべて含むユーザーを検索します")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("「確定」を押すか、Enterキーでタグを追加")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    // 共通点フィルター
                    Section(header: Text("共通点")) {
                        Picker("共通点", selection: $commonPointsMode) {
                            Text("指定なし").tag("none")
                            Text("1個以上").tag("1+")
                            Text("3個以上").tag("3+")
                            Text("5個以上").tag("5+")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // リセットボタン
                    Section {
                        Button(action: resetFilters) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.counterclockwise")
                                Text("フィルターをリセット")
                                Spacer()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("適用") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                // UserServiceから保存済みのフィルターを読み込み
                hashtagFilter = userService.hashtagFilter
            }
            .onChange(of: hashtagInput) { newValue in
                showSuggestions = !newValue.isEmpty && !filteredSuggestions.isEmpty
            }
        }
    }
    
    // 入力文字をハイライト表示
    @ViewBuilder
    private func highlightedText(suggestion: String, input: String) -> some View {
        let normalizedInput = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "#", with: "")
            .lowercased()
        
        let normalizedSuggestion = suggestion
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
        
        HStack(spacing: 2) {
            Text("#")
                .foregroundColor(.brandPurple)
            
            if normalizedSuggestion.contains(normalizedInput) {
                Text(suggestion)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            } else {
                Text(suggestion)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func addHashtagFilter() {
        let trimmed = hashtagInput
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        
        if !trimmed.isEmpty && !hashtagFilter.contains(trimmed) {
            hashtagFilter.append(trimmed)
            hashtagInput = ""
            showSuggestions = false
            // フォーカスを維持して連続入力を可能に
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }
    
    private func addSuggestion(_ suggestion: String) {
        if !hashtagFilter.contains(suggestion) {
            hashtagFilter.append(suggestion)
            hashtagInput = ""
            showSuggestions = false
        }
    }
    
    private func resetFilters() {
        filterConditions = [:]
        hashtagFilter = []
        hashtagInput = ""
        commonPointsMode = "none"
        minCommonPoints = 0
        maxDistance = 100
    }
    
    private func applyFilters() {
        // 共通点フィルターの数値変換
        switch commonPointsMode {
        case "1+": minCommonPoints = 1
        case "3+": minCommonPoints = 3
        case "5+": minCommonPoints = 5
        default: minCommonPoints = 0
        }
        
        // UserServiceにハッシュタグフィルターを保存
        userService.hashtagFilter = hashtagFilter
    }
}

// MARK: - フィルター用確定済みハッシュタグチップ
struct FilterConfirmedChip: View {
    let text: String
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(text)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.brandPurple)
        .cornerRadius(20)
    }
}
