import Foundation

struct ProfileItemDefinition {
    let key: String
    let displayName: String
    let options: [String]
}

struct ProfileConstants {
    // 30個のプロフィール項目定義
    static let items: [ProfileItemDefinition] = [
        // 基本
        .init(key: "residence", displayName: "居住地", options: ["北海道", "青森", "岩手", "宮城", "秋田", "山形", "福島", "茨城", "栃木", "群馬", "埼玉", "千葉", "東京", "神奈川", "新潟", "富山", "石川", "福井", "山梨", "長野", "岐阜", "静岡", "愛知", "三重", "滋賀", "京都", "大阪", "兵庫", "奈良", "和歌山", "鳥取", "島根", "岡山", "広島", "山口", "徳島", "香川", "愛媛", "高知", "福岡", "佐賀", "長崎", "熊本", "大分", "宮崎", "鹿児島", "沖縄", "海外"]),
        .init(key: "age", displayName: "年齢", options: (18...80).map { "\($0)歳" }),
        .init(key: "height", displayName: "身長", options: (130...200).map { "\($0)cm" }),
        .init(key: "bodyType", displayName: "体型", options: ["細め", "普通", "グラマー", "筋肉質", "ぽっちゃり", "太め"]),
        .init(key: "bloodType", displayName: "血液型", options: ["A型", "B型", "O型", "AB型", "不明"]),
        .init(key: "occupation", displayName: "職業", options: ["学生", "会社員", "公務員", "経営者・役員", "自営業", "フリーランス", "専門職", "医療関係", "IT関連", "飲食・サービス", "販売", "美容関係", "保育・教育", "福祉・介護", "公務員", "主婦・主夫", "その他"]),
        .init(key: "education", displayName: "学歴", options: ["高校卒", "短大/専門卒", "大学卒", "大学院卒", "その他"]),
        .init(key: "income", displayName: "年収", options: ["200万円未満", "200~400万円", "400~600万円", "600~800万円", "800~1000万円", "1000~1500万円", "1500万円以上", "内緒"]),
        
        // ライフスタイル
        .init(key: "holiday", displayName: "休日", options: ["土日", "平日", "不定期", "シフト制"]),
        .init(key: "alcohol", displayName: "お酒", options: ["飲まない", "時々飲む", "飲む"]),
        .init(key: "smoking", displayName: "タバコ", options: ["吸わない", "時々吸う", "吸う", "非喫煙者の前では吸わない"]),
        .init(key: "housemate", displayName: "同居人", options: ["一人暮らし", "実家暮らし", "ペットと一緒", "友達とシェア", "その他"]),
        .init(key: "siblings", displayName: "兄弟姉妹", options: ["長男・長女", "中間子", "末っ子", "一人っ子"]),
        
        // 恋愛・結婚観
        .init(key: "marriageHistory", displayName: "結婚歴", options: ["未婚", "離婚歴あり", "死別"]),
        .init(key: "children", displayName: "子供の有無", options: ["なし", "あり(同居)", "あり(別居)"]),
        .init(key: "wantKids", displayName: "子供が欲しいか", options: ["欲しい", "欲しくない", "相手と相談", "こだわらない"]),
        .init(key: "housework", displayName: "家事・育児", options: ["積極的に参加したい", "分担したい", "相手に任せたい", "得意な方がやる"]),
        .init(key: "meetPreference", displayName: "出会うまでの希望", options: ["気が合えばすぐ会いたい", "メッセージを重ねてから", "通話してから", "まずはビデオ通話"]),
        .init(key: "dateCost", displayName: "デート費用", options: ["男性が全て払う", "男性が多めに払う", "割り勘", "持っている方が払う", "相手と相談"]),
        
        // 性格・趣味
        .init(key: "personality", displayName: "性格", options: ["明るい", "優しい", "冷静", "真面目", "ユーモアがある", "マイペース", "社交的", "内向的", "ポジティブ", "責任感が強い"]),
        .init(key: "sociability", displayName: "社交性", options: ["高い", "普通", "人見知り", "狭く深く"]),
        .init(key: "hobby", displayName: "趣味", options: ["旅行", "音楽", "映画", "グルメ", "カフェ", "ゲーム", "アニメ", "スポーツ", "読書", "カメラ", "アウトドア", "ドライブ", "料理", "ショッピング", "アート", "ジム", "その他"]),
        .init(key: "charmPoint", displayName: "チャームポイント", options: ["笑顔", "声", "目", "手", "スタイル", "性格", "えくぼ", "髪"]),
        
        // 好み
        .init(key: "music", displayName: "好きな音楽", options: ["J-POP", "ロック", "ヒップホップ", "R&B", "K-POP", "ジャズ", "クラシック", "EDM", "アニソン", "洋楽", "その他"]),
        .init(key: "movie", displayName: "好きな映画ジャンル", options: ["アクション", "コメディ", "恋愛", "ホラー", "SF", "ミステリー", "ドキュメンタリー", "アニメ", "その他"]),
        
        // その他
        .init(key: "idealDate", displayName: "理想のデート", options: ["カフェでお茶", "映画館", "居酒屋で乾杯", "遊園地", "ドライブ", "家でのんびり", "ショッピング", "アクティブにスポーツ", "美術館・博物館"]),
        .init(key: "motto", displayName: "座右の銘", options: ["一期一会", "七転び八起き", "継続は力なり", "なんとかなる", "思い立ったが吉日", "特になし"]),
        .init(key: "fetish", displayName: "フェチ", options: ["声", "手", "匂い", "筋肉", "脚", "髪", "鎖骨", "笑顔", "特になし"]),
        .init(key: "weakness", displayName: "苦手なもの", options: ["虫", "お化け", "高いところ", "絶叫マシン", "人混み", "嘘", "特になし"]),
        .init(key: "holidaySpend", displayName: "休日の過ごし方", options: ["家でゴロゴロ", "友達と遊ぶ", "ショッピング", "ジム・運動", "趣味に没頭", "勉強", "掃除・洗濯", "旅行"])
    ]
}
