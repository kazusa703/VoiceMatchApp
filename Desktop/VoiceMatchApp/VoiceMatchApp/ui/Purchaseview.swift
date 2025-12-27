import SwiftUI

struct PurchaseView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // ヘッダー
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("VoiceMatch プレミアム")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.top, 40)
                
                // 特典一覧
                VStack(alignment: .leading, spacing: 16) {
                    PremiumFeatureRow(icon: "waveform", text: "すべてのボイスエフェクトが使い放題")
                    PremiumFeatureRow(icon: "heart.fill", text: "1日100いいね（通常は10回）")
                    PremiumFeatureRow(icon: "eye.slash.fill", text: "足あと機能")
                    PremiumFeatureRow(icon: "xmark.circle.fill", text: "広告なし")
                }
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Spacer()
                
                // 購入ボタン
                VStack(spacing: 12) {
                    Button(action: {
                        // TODO: 実際の課金処理
                        Task {
                            // await purchaseManager.purchase()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text("月額プラン")
                                .font(.headline)
                            Text("¥980 / 月")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // TODO: 復元処理
                        Task {
                            // await purchaseManager.restore()
                        }
                    }) {
                        Text("購入を復元")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("いつでもキャンセルできます")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
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

struct PremiumFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}
