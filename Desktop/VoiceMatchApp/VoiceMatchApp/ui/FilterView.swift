import SwiftUI

struct FilterView: View {
    @Binding var filterConditions: [String: String]
    @Binding var minCommonPoints: Int
    @Binding var commonPointsMode: String
    @Binding var maxDistance: Double
    
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @State private var showPaywall = false
    @State private var showLocationAlert = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("閉じる") { dismiss() }.foregroundColor(.primary)
                Spacer()
                Text("条件設定").font(.headline)
                Spacer()
                Text("閉じる").opacity(0)
            }
            .padding()
            .background(Color.white)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // --- 共通点 ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("共通点の条件").font(.headline).foregroundColor(.secondary)
                        
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "sparkles").foregroundColor(.yellow)
                                Text("共通点: \(minCommonPoints)個以上").fontWeight(.bold)
                                Spacer()
                            }
                            
                            Slider(value: Binding(
                                get: { Double(minCommonPoints) },
                                set: { minCommonPoints = Int($0) }
                            ), in: 0...10, step: 1).tint(.brandPurple)
                            
                            Picker("モード", selection: $commonPointsMode) {
                                Text("〜個以上").tag("以上")
                                Text("ピッタリ").tag("ピッタリ")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding().background(Color.white).cornerRadius(20)
                    }
                    
                    // --- 距離 ---
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("距離で絞り込む").font(.headline).foregroundColor(.secondary)
                            Button(action: { showLocationAlert = true }) {
                                Image(systemName: "info.circle").foregroundColor(.gray)
                            }
                        }
                        
                        VStack(spacing: 20) {
                            HStack {
                                Text("検索範囲")
                                Spacer()
                                Text(maxDistance >= 100 ? "制限なし" : "\(Int(maxDistance))km以内")
                                    .foregroundColor(.brandPurple).fontWeight(.bold)
                            }
                            
                            if purchaseManager.isPro {
                                Slider(value: Binding(
                                    get: { maxDistance },
                                    set: { val in
                                        maxDistance = val
                                        if val < 100 && userService.currentUserProfile?.location == nil {
                                            showLocationAlert = true
                                        }
                                    }
                                ), in: 5...100, step: 5).tint(.brandPurple)
                            } else {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "lock.fill")
                                        Text("距離フィルタはProプラン限定機能です")
                                    }.font(.caption).foregroundColor(.secondary)
                                    
                                    Button("Proプランを見る") { showPaywall = true }
                                        .font(.caption.bold()).foregroundColor(.brandPurple)
                                }
                            }
                        }
                        .padding().background(Color.white).cornerRadius(20)
                    }
                    
                    // --- 必須条件 ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("必須条件 (絶対に譲れない項目)").font(.headline).foregroundColor(.secondary)
                        
                        VStack(spacing: 0) {
                            if filterConditions.isEmpty {
                                Text("設定なし").foregroundColor(.gray).padding().frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(Array(filterConditions.keys), id: \.self) { key in
                                    if let def = ProfileConstants.items.first(where: { $0.key == key }) {
                                        HStack {
                                            Text(def.displayName).foregroundColor(.secondary)
                                            Spacer()
                                            Text(filterConditions[key] ?? "").fontWeight(.medium)
                                            Button(action: { filterConditions.removeValue(forKey: key) }) {
                                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                            }
                                        }
                                        .padding()
                                        Divider()
                                    }
                                }
                            }
                            
                            // 条件追加メニュー
                            Menu {
                                if !purchaseManager.isPro && filterConditions.count >= 1 {
                                    Button("無料プランは1つまでです") {
                                        alertMessage = "無料プランでは絞り込み条件は1つまでです。"
                                        showAlert = true
                                    }
                                } else {
                                    ForEach(ProfileConstants.items, id: \.key) { item in
                                        Menu(item.displayName) {
                                            ForEach(Array(Set(item.options)).sorted(), id: \.self) { option in
                                                Button(option) { filterConditions[item.key] = option }
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("条件を追加する")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundColor(.primary).padding()
                            }
                            
                            // Pro特典
                            HStack {
                                Image(systemName: "crown.fill").foregroundColor(.yellow)
                                Text("Proなら必須条件を無制限に追加可能")
                                    .font(.caption)
                                    .foregroundColor(.brandPurple)
                            }
                            .padding()
                        }
                        .background(Color.white).cornerRadius(20)
                    }
                    
                    Button("条件をリセット") {
                        filterConditions.removeAll()
                        minCommonPoints = 0
                        maxDistance = 100
                    }
                    .foregroundColor(.red).padding(.top)
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            
            Button(action: { dismiss() }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("この条件で検索して探す")
                }
                .fontWeight(.bold).frame(maxWidth: .infinity).padding()
                .background(Color.brandPurple).foregroundColor(.white).cornerRadius(30)
            }
            .padding()
            .background(Color.white)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("制限", isPresented: $showAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("Proプランを見る") { showPaywall = true }
        } message: { Text(alertMessage) }
        .alert("位置情報", isPresented: $showLocationAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("距離で絞り込むには位置情報が必要です。")
        }
    }
}
