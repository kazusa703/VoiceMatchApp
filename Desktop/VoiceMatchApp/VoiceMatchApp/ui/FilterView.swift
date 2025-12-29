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
                    Section(header: Text("興味・関心で絞り込み")) {
                        FilterHashtagSection(selectedTags: $hashtagFilter)
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
                hashtagFilter = userService.hashtagFilter
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func resetFilters() {
        filterConditions = [:]
        hashtagFilter = []
        commonPointsMode = "none"
        minCommonPoints = 0
        maxDistance = 100
    }
    
    private func applyFilters() {
        switch commonPointsMode {
        case "1+": minCommonPoints = 1
        case "3+": minCommonPoints = 3
        case "5+": minCommonPoints = 5
        default: minCommonPoints = 0
        }
        userService.hashtagFilter = hashtagFilter
    }
}

// MARK: - フィルター用確定済みハッシュタグチップ

struct FilterConfirmedChip: View {
    let text: String
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
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

// MARK: - WrappingHStack（Form内でも動作する折り返しレイアウト）

struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    @State private var totalHeight: CGFloat = .zero
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return Color.clear
        }
    }
}

// MARK: - フィルター用ハッシュタグセクション

struct FilterHashtagSection: View {
    @Binding var selectedTags: [String]
    @State private var showTagSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 選択済みタグ
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中のタグ（\(selectedTags.count)個）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    WrappingHStack(items: selectedTags) { tag in
                        FilterConfirmedChip(text: tag) {
                            selectedTags.removeAll { $0 == tag }
                        }
                    }
                }
            }
            
            // タグ選択ボタン
            Button(action: { showTagSelection = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.brandPurple)
                    Text(selectedTags.isEmpty ? "タグを選択して絞り込む" : "タグを追加")
                        .foregroundColor(.brandPurple)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // ヒント
            Text("選択したタグをすべて含むユーザーを表示します")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showTagSelection) {
            FilterTagSelectionView(selectedTags: $selectedTags)
        }
    }
}

// MARK: - フィルター用タグ選択ビュー

struct FilterTagSelectionView: View {
    @Binding var selectedTags: [String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(HashtagCategories.all) { category in
                        FilterCategorySection(
                            category: category,
                            selectedTags: $selectedTags
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("興味で絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - フィルター用カテゴリセクション

struct FilterCategorySection: View {
    let category: HashtagCategory
    @Binding var selectedTags: [String]
    
    @State private var isExpanded = false
    private let initialDisplayCount = 7
    
    private var displayedTags: [String] {
        if isExpanded {
            return category.tags
        } else {
            return Array(category.tags.prefix(initialDisplayCount))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // カテゴリヘッダー
            HStack(spacing: 8) {
                Text(category.icon)
                    .font(.title2)
                Text(category.name)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // タグ一覧
            FlowLayout(spacing: 10) {
                ForEach(displayedTags, id: \.self) { tag in
                    FilterTagButton(
                        tag: tag,
                        isSelected: selectedTags.contains(tag),
                        onTap: { toggleTag(tag) }
                    )
                }
            }
            
            // もっと見る / 表示を減らす
            if category.tags.count > initialDisplayCount {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text(isExpanded ? "表示を減らす" : "もっと見る")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.removeAll { $0 == tag }
        } else {
            selectedTags.append(tag)
        }
    }
}

// MARK: - フィルター用タグボタン

struct FilterTagButton: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(tag)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? Color.brandPurple
                        : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.brandPurple : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(20)
        }
    }
}
