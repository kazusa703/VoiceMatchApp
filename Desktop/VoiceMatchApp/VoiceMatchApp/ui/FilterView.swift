import SwiftUI

struct FilterView: View {
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @Binding var filterConditions: [String: String]
    @Binding var minCommonPoints: Int
    @Binding var commonPointsMode: String
    @Binding var maxDistance: Double
    
    // 自由入力フィルター
    @State private var freeInputFilters: [String: [String]] = [:]
    
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
        
        // 3. 自由入力フィルター（AND検索・空白無視）
        for (key, filterValues) in freeInputFilters {
            if filterValues.isEmpty { continue }
            users = users.filter { user in
                let userValues = user.profileFreeItems[key] ?? []
                // 入力されたタグすべてを含んでいるか (AND)
                return filterValues.allSatisfy { filterValue in
                    let normalizedFilter = filterValue
                        .replacingOccurrences(of: " ", with: "")
                        .replacingOccurrences(of: "　", with: "")
                        .lowercased()
                    
                    return userValues.contains { userTag in
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
        // Pickerの選択状態(commonPointsMode)から一時的に数値を判定して計算
        let currentMinPoints: Int
        switch commonPointsMode {
        case "1+": currentMinPoints = 1
        case "3+": currentMinPoints = 3
        case "5+": currentMinPoints = 5
        case "ピッタリ": currentMinPoints = minCommonPoints // 将来的な拡張用
        default: currentMinPoints = 0
        }
        
        if currentMinPoints > 0 {
            users = users.filter { user in
                let commonPoints = userService.calculateCommonPoints(with: user)
                if commonPointsMode == "ピッタリ" {
                    return commonPoints == currentMinPoints
                } else {
                    return commonPoints >= currentMinPoints
                }
            }
        }
        
        return users.count
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヒット数表示（ヘッダーの下、ScrollViewの前）
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
                    
                    // 自由入力フィルター
                    Section(header: Text("趣味・好み")) {
                        Text("入力した内容と一致するユーザーを検索します（AND検索）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(ProfileConstants.freeInputItems, id: \.key) { itemDef in
                            FreeInputFilterRow(
                                itemDef: itemDef,
                                selectedValues: Binding(
                                    get: { freeInputFilters[itemDef.key] ?? [] },
                                    set: { freeInputFilters[itemDef.key] = $0 }
                                ),
                                suggestions: userService.getSuggestionsForKey(itemDef.key)
                            )
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
                                Text("フィルターをリセット")
                                    .foregroundColor(.red)
                                Spacer()
                            }
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
                freeInputFilters = userService.freeInputFilters
            }
        }
    }
    
    private func resetFilters() {
        filterConditions = [:]
        freeInputFilters = [:]
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
        
        // UserServiceに自由入力フィルターを保存
        userService.freeInputFilters = freeInputFilters
    }
}

// MARK: - 自由入力フィルター行

struct FreeInputFilterRow: View {
    let itemDef: ProfileItemDefinition
    @Binding var selectedValues: [String]
    let suggestions: [String]
    
    @State private var inputText = ""
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool
    
    // フィルタリングされたサジェスト（空白を無視して部分一致）
    private var filteredSuggestions: [String] {
        if inputText.isEmpty {
            return []
        }
        
        // 入力から空白を除去
        let normalizedInput = inputText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "") // 全角空白も
            .lowercased()
        
        return suggestions.filter { suggestion in
            // すでに選択済みは除外
            guard !selectedValues.contains(suggestion) else { return false }
            
            // サジェストから空白を除去
            let normalizedSuggestion = suggestion
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "　", with: "")
                .lowercased()
            
            // 空白除去版で部分一致チェック OR 通常の部分一致
            return normalizedSuggestion.contains(normalizedInput) ||
                   suggestion.lowercased().contains(inputText.lowercased())
        }.prefix(5).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(itemDef.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
            
            // 選択済みタグ
            if !selectedValues.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedValues, id: \.self) { value in
                        HStack(spacing: 4) {
                            Text(value)
                                .font(.caption)
                            
                            Button(action: {
                                selectedValues.removeAll { $0 == value }
                            }) {
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
            }
            
            // 入力欄
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack {
                        TextField(itemDef.placeholder, text: $inputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isFocused)
                            .onChange(of: inputText) { _ in
                                showSuggestions = !inputText.isEmpty && !filteredSuggestions.isEmpty
                            }
                            .onSubmit {
                                addValue(inputText)
                            }
                        
                        Button(action: {
                            addValue(inputText)
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.brandPurple)
                                .font(.title3)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    // サジェストリスト
                    if showSuggestions && isFocused {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredSuggestions, id: \.self) { suggestion in
                                Button(action: {
                                    addValue(suggestion)
                                }) {
                                    HStack {
                                        // ハイライト表示
                                        highlightedText(suggestion: suggestion, input: inputText)
                                        Spacer()
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
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // 入力文字をハイライト表示（一致度に応じてスタイル変更）
    @ViewBuilder
    private func highlightedText(suggestion: String, input: String) -> some View {
        let normalizedInput = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
        
        let normalizedSuggestion = suggestion
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .lowercased()
        
        // マッチしている場合は太字で表示
        if normalizedSuggestion.contains(normalizedInput) {
            HStack(spacing: 0) {
                Text(suggestion)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
            }
        } else {
            HStack(spacing: 0) {
                Text(suggestion)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func addValue(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !selectedValues.contains(trimmed) {
            selectedValues.append(trimmed)
            inputText = ""
            showSuggestions = false
        }
    }
}
