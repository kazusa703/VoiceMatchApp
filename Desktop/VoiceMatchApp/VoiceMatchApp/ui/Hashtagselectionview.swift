import SwiftUI

// MARK: - ハッシュタグ選択ビュー（カテゴリ別）

struct HashtagSelectionView: View {
    @Binding var selectedTags: [String]
    @Environment(\.dismiss) var dismiss
    
    let minSelection = 5
    let maxSelection = 100
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerSection
                
                // カテゴリリスト
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(HashtagCategories.all) { category in
                            CategorySection(
                                category: category,
                                selectedTags: $selectedTags,
                                maxSelection: maxSelection
                            )
                        }
                    }
                    .padding()
                }
                
                // 下部ボタン
                bottomButton
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("スキップ") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("興味関心は？")
                .font(.title)
                .fontWeight(.bold)
            
            Text("好きなことを紹介しよう。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
    
    // MARK: - Bottom Button
    
    private var bottomButton: some View {
        VStack(spacing: 8) {
            Divider()
            
            Button(action: { dismiss() }) {
                Text("次へ \(selectedTags.count) / \(minSelection)")
                    .font(.headline)
                    .foregroundColor(selectedTags.count >= minSelection ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        selectedTags.count >= minSelection
                            ? Color.brandPurple
                            : Color(uiColor: .systemGray5)
                    )
                    .cornerRadius(30)
            }
            .disabled(selectedTags.count < minSelection)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - カテゴリセクション

struct CategorySection: View {
    let category: HashtagCategory
    @Binding var selectedTags: [String]
    let maxSelection: Int
    
    @State private var isExpanded = false
    
    // 初期表示数
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
                    TagButton(
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
        } else if selectedTags.count < maxSelection {
            selectedTags.append(tag)
        }
    }
}

// MARK: - タグボタン

struct TagButton: View {
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

// MARK: - プロフィール編集用のコンパクト版

struct HashtagEditSection: View {
    @Binding var selectedTags: [String]
    @State private var showFullSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 説明
            HStack {
                Text("興味・関心（\(selectedTags.count)個選択中）")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showFullSelection = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("編集")
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandPurple)
                }
            }
            
            // 選択済みタグを表示
            if selectedTags.isEmpty {
                Text("タップして興味を追加しましょう")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(10)
                    .onTapGesture {
                        showFullSelection = true
                    }
            } else {
                TagDisplayFlowLayout(tags: selectedTags)
                    .onTapGesture {
                        showFullSelection = true
                    }
            }
        }
        .sheet(isPresented: $showFullSelection) {
            HashtagSelectionView(selectedTags: $selectedTags)
        }
    }
}

// MARK: - タグ表示用FlowLayout

struct TagDisplayFlowLayout: View {
    let tags: [String]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .foregroundColor(.brandPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandPurple.opacity(0.1))
                    .cornerRadius(15)
            }
        }
    }
}
