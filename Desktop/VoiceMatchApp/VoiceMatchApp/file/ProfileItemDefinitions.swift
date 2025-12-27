import Foundation

// MARK: - プロフィール項目の種類
enum ProfileItemType {
    case selection      // 選択式（単一選択）
    case freeInput      // 自由入力（複数可）
}

// MARK: - プロフィール項目定義
struct ProfileItemDefinition: Identifiable {
    var id: String { key }
    let key: String
    let displayName: String
    let type: ProfileItemType
    let options: [String]  // 選択式の場合の選択肢
    let placeholder: String // 自由入力の場合のプレースホルダー
    let maxInputCount: Int  // 自由入力の最大数
}

struct ProfileConstants {
    static let items: [ProfileItemDefinition] = [
        // === 選択式項目 ===
        ProfileItemDefinition(
            key: "age",
            displayName: "年齢",
            type: .selection,
            options: ["18〜22歳", "23〜25歳", "26〜29歳", "30〜34歳", "35〜39歳", "40〜44歳", "45〜49歳", "50歳以上"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "height",
            displayName: "身長",
            type: .selection,
            options: ["〜150cm", "151〜155cm", "156〜160cm", "161〜165cm", "166〜170cm", "171〜175cm", "176〜180cm", "181〜185cm", "186cm〜"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "bloodType",
            displayName: "血液型",
            type: .selection,
            options: ["A型", "B型", "O型", "AB型"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "mbti",
            displayName: "MBTI",
            type: .selection,
            options: ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "drinking",
            displayName: "お酒",
            type: .selection,
            options: ["飲む", "たまに飲む", "飲まない"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "smoking",
            displayName: "タバコ",
            type: .selection,
            options: ["吸う", "たまに吸う", "吸わない"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "occupation",
            displayName: "職業",
            type: .selection,
            options: ["会社員", "公務員", "自営業", "経営者", "フリーランス", "学生", "クリエイター", "医療関係", "教育関係", "IT関係", "その他"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "education",
            displayName: "学歴",
            type: .selection,
            options: ["高校卒", "専門学校卒", "短大卒", "大学卒", "大学院卒"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "marriageIntent",
            displayName: "結婚願望",
            type: .selection,
            options: ["すぐにでも", "2〜3年以内", "いつかは", "わからない"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "childrenIntent",
            displayName: "子供",
            type: .selection,
            options: ["欲しい", "相手による", "欲しくない", "わからない"],
            placeholder: "",
            maxInputCount: 1
        ),
        ProfileItemDefinition(
            key: "livingWith",
            displayName: "同居人",
            type: .selection,
            options: ["一人暮らし", "実家暮らし", "友人と同居", "ペットと暮らしている"],
            placeholder: "",
            maxInputCount: 1
        ),
        
        // === 自由入力項目 ===
        ProfileItemDefinition(
            key: "favoriteMovies",
            displayName: "好きな映画",
            type: .freeInput,
            options: [],
            placeholder: "例: カリブの海賊",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "favoriteMusic",
            displayName: "好きな音楽・アーティスト",
            type: .freeInput,
            options: [],
            placeholder: "例: YOASOBI",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "favoriteAnime",
            displayName: "好きなアニメ・漫画",
            type: .freeInput,
            options: [],
            placeholder: "例: 鬼滅の刃",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "favoriteGames",
            displayName: "好きなゲーム",
            type: .freeInput,
            options: [],
            placeholder: "例: ポケモン",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "hobbies",
            displayName: "趣味",
            type: .freeInput,
            options: [],
            placeholder: "例: カフェ巡り",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "favoriteFood",
            displayName: "好きな食べ物",
            type: .freeInput,
            options: [],
            placeholder: "例: ラーメン",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "favoriteBooks",
            displayName: "好きな本・作家",
            type: .freeInput,
            options: [],
            placeholder: "例: 東野圭吾",
            maxInputCount: 10
        ),
        ProfileItemDefinition(
            key: "favoriteSports",
            displayName: "好きなスポーツ",
            type: .freeInput,
            options: [],
            placeholder: "例: サッカー",
            maxInputCount: 10
        )
    ]
    
    // 選択式項目のみ
    static var selectionItems: [ProfileItemDefinition] {
        items.filter { $0.type == .selection }
    }
    
    // 自由入力項目のみ
    static var freeInputItems: [ProfileItemDefinition] {
        items.filter { $0.type == .freeInput }
    }
    
    static func getItem(by key: String) -> ProfileItemDefinition? {
        return items.first { $0.key == key }
    }
}
