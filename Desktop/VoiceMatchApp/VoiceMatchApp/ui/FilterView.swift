import SwiftUI

struct FilterView: View {
    @Binding var filterConditions: [String: String]
    @Binding var minCommonPoints: Int
    @Binding var commonPointsMode: String
    // 追加: 距離フィルタ用のバインディング
    @Binding var maxDistance: Double
    
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showPaywall = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    // 項目選択シート用
    @State private var selectedDefinition: ProfileItemDefinition?
    
    var body: some View {
        VStack(spacing: 0) {
            // カスタムナビゲーションバー
            HStack {
                Button("閉じる") { dismiss() }
                    .foregroundColor(.primary)
                Spacer()
                Text("条件設定")
                    .font(.headline)
                Spacer()
                // レイアウト調整用のダミー
                Text("閉じる").opacity(0)
            }
            .padding()
            .background(Color.white)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // --- 共通点の条件 ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("共通点の条件")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("共通点: \(minCommonPoints)個以上")
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            
                            // カスタムスライダー
                            Slider(value: Binding(
                                get: { Double(minCommonPoints) },
                                set: { minCommonPoints = Int($0) }
                            ), in: 0...10, step: 1)
                            .tint(.brandPurple)
                            
                            HStack {
                                Text("0個")
                                Spacer()
                                Text("10個")
                            }
                            .font(.caption)
                            .foregroundColor(.gray)
                            
                            // モード切り替え
                            Picker("モード", selection: $commonPointsMode) {
                                Text("〜個以上").tag("以上")
                                Text("ピッタリ").tag("ピッタリ")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        
                        Text("共通点が設定値以上の相手を表示します。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    
                    // --- 距離で絞り込む (追加部分) ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("距離で絞り込む")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 20) {
                            HStack {
                                Text("検索範囲")
                                Spacer()
                                Text(maxDistance >= 100 ? "制限なし" : "\(Int(maxDistance))km以内")
                                    .foregroundColor(.brandPurple)
                                    .fontWeight(.bold)
                            }
                            
                            ZStack {
                                // スライダー本体
                                Slider(value: $maxDistance, in: 1...100, step: 5)
                                    .tint(.brandPurple)
                                    // Proでなければ操作不能に見せる
                                    .disabled(!purchaseManager.isPro)
                                
                                // 無料ユーザー向けのタップ検知用オーバーレイ
                                if !purchaseManager.isPro {
                                    Color.white.opacity(0.01) // 透明な膜
                                        .frame(height: 44) // タップ領域を確保
                                        .onTapGesture {
                                            showPaywall = true // 課金画面を表示
                                        }
                                }
                            }
                            
                            if !purchaseManager.isPro {
                                HStack {
                                    Image(systemName: "lock.fill")
                                    Text("距離フィルタはProプラン限定機能です")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            } else {
                                // Proユーザー向けの目盛り表示など
                                HStack {
                                    Text("1km")
                                    Spacer()
                                    Text("制限なし")
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    
                    // --- 必須条件 ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("必須条件 (絶対に譲れない項目)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 0) {
                            if filterConditions.isEmpty {
                                Text("設定なし")
                                    .foregroundColor(.gray)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(Array(filterConditions.keys), id: \.self) { key in
                                    if let def = ProfileConstants.items.first(where: { $0.key == key }) {
                                        HStack {
                                            Text(def.displayName)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(filterConditions[key] ?? "")
                                                .fontWeight(.medium)
                                            
                                            Button(action: {
                                                filterConditions.removeValue(forKey: key)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding()
                                        Divider()
                                    }
                                }
                            }
                            
                            Button(action: {
                                // 制限チェック
                                if !purchaseManager.isPro && !filterConditions.isEmpty {
                                    alertMessage = "無料プランでは絞り込み条件は1つまでです。"
                                    showAlert = true
                                } else {
                                    // 項目選択画面を開くためのロジックなど
                                    // ここでは項目一覧を開くシートを実装します
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("条件を追加する")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.primary)
                                .padding()
                            }
                            // 項目選択シートのトリガーとしてMenuを使う
                            .contextMenu {
                                ForEach(ProfileConstants.items, id: \.key) { item in
                                    Menu(item.displayName) {
                                        ForEach(item.options, id: \.self) { option in
                                            Button(option) {
                                                filterConditions[item.key] = option
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        
                        if !purchaseManager.isPro {
                            HStack {
                                Image(systemName: "crown.fill").foregroundColor(.yellow)
                                Text("Proなら必須条件を無制限に追加可能")
                                    .font(.caption)
                                    .foregroundColor(.brandPurple)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(20)
                            .onTapGesture { showPaywall = true }
                        }
                    }
                    
                    // リセット
                    Button("条件をリセット") {
                        filterConditions.removeAll()
                        minCommonPoints = 0
                        commonPointsMode = "以上"
                        // 距離もリセットする場合はここに追加
                        // maxDistance = 100
                    }
                    .foregroundColor(.red)
                    .padding(.top)
                    
                    Spacer(minLength: 80)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            
            // 下部の検索ボタン
            VStack {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("この条件で検索して探す")
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPurple)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                }
                .padding()
            }
            .background(Color.white)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("制限", isPresented: $showAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("Proプランを見る") { showPaywall = true }
        } message: {
            Text(alertMessage)
        }
    }
}
