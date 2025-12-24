import SwiftUI

struct PlanComparisonView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // ヘッダー
                VStack(spacing: 10) {
                    Text("プランの選択")
                        .font(.largeTitle.bold())
                    Text("Proプランで制限を解除しよう")
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // プラン比較表
                HStack(spacing: 20) {
                    // 無料プラン
                    PlanCard(title: "Free", price: "¥0", features: [
                        "マッチング: 12時間に5回まで", // ★修正
                        "共通点フィルタ: なし",
                        "広告: あり"
                    ], isPro: false)
                    
                    // Proプラン
                    PlanCard(title: "Pro", price: "¥980/月", features: [
                        "マッチング: 12時間に100回", // ★修正
                        "共通点・職業フィルタ: あり",
                        "広告: なし"
                    ], isPro: true)
                }
                
                Spacer()
                
                // 課金ボタン（RevenueCatと連携済みのPaywallViewを使うのが安全ですが、ここにも簡易ボタンを配置）
                // ※実際はPaywallViewを呼び出すのがベストです
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// デザイン用カードコンポーネント（変更なし）
struct PlanCard: View {
    let title: String
    let price: String
    let features: [String]
    let isPro: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Text(title)
                .font(.headline)
                .foregroundColor(isPro ? .brandPurple : .primary)
            Text(price)
                .font(.title2.bold())
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top) {
                        Image(systemName: isPro ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isPro ? .brandPurple : .gray)
                            .font(.caption)
                        Text(feature)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .frame(height: 250)
        .background(Color.adaptiveBackground)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isPro ? Color.brandPurple : Color.gray.opacity(0.3), lineWidth: isPro ? 2 : 1)
        )
        .shadow(color: isPro ? Color.brandPurple.opacity(0.3) : Color.black.opacity(0.05), radius: 10)
    }
}
