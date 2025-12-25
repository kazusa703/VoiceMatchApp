import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark").foregroundColor(.primary).padding()
                }
            }
            
            Spacer()
            
            Image(systemName: "crown.fill").font(.system(size: 80)).foregroundColor(.yellow)
            
            Text("Proプランにアップグレード").font(.title).fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "infinity", text: "アプローチ送信し放題")
                FeatureRow(icon: "bolt.fill", text: "12時間の待機時間なし")
                FeatureRow(icon: "star.fill", text: "プロフィールの優先表示")
                FeatureRow(icon: "mic.fill", text: "高音質ボイスメッセージ")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                // purchaseProを呼び出し
                purchaseManager.purchasePro()
                dismiss()
            }) {
                VStack(spacing: 4) {
                    Text("Proプランに登録").fontWeight(.bold)
                    Text("$9.99 / 月").font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient.instaGradient)
                .cornerRadius(30)
            }
            .padding(.horizontal)
            
            Button("購入を復元する") { purchaseManager.restorePurchases() }
                .font(.caption).foregroundColor(.gray)
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.brandPurple).frame(width: 24)
            Text(text)
        }
    }
}
