import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) { // 閉じるボタン用にZStackを使用
            ScrollView {
                VStack(spacing: 30) {
                    // ヘッダー画像
                    Image(systemName: "crown.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.yellow)
                        .padding(.top, 60)
                        .shadow(color: .orange, radius: 10)
                    
                    Text("Proプランにアップグレード")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // メリット一覧
                    VStack(alignment: .leading, spacing: 20) {
                        FeatureRow(icon: "infinity", text: "アプローチ送信し放題")
                        FeatureRow(icon: "bolt.fill", text: "12時間の待機時間なし")
                        FeatureRow(icon: "star.fill", text: "プロフィールの優先表示")
                        FeatureRow(icon: "mic.fill", text: "高音質ボイスメッセージ")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 30)
                    
                    // 購入ボタン
                    if let package = purchaseManager.offerings?.current?.monthly {
                        Button(action: { purchase(package: package) }) {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                VStack {
                                    Text("Proプランに登録")
                                        .fontWeight(.bold)
                                    Text(package.storeProduct.localizedPriceString + " / 月")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(LinearGradient.instaGradient)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                        .padding(.horizontal)
                        .shadow(radius: 5)
                        .disabled(isPurchasing)
                    } else {
                        // 商品情報が取得できていない場合
                        VStack {
                            Text("プラン情報を読み込み中...")
                                .foregroundColor(.gray)
                            Button("再読み込み") {
                                purchaseManager.fetchOfferings()
                            }
                            .font(.caption)
                            .padding(.top, 4)
                        }
                        .onAppear {
                            purchaseManager.fetchOfferings()
                        }
                    }
                    
                    // 復元ボタン
                    Button("購入を復元する") {
                        restore()
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            
            // ★追加: 閉じるボタン
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding()
            }
        }
        .presentationDetents([.large])
        .alert("完了", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Proプランへのアップグレードありがとうございます！")
        }
    }
    
    private func purchase(package: Package) {
        isPurchasing = true
        errorMessage = nil
        
        Task {
            do {
                try await purchaseManager.purchase(package: package)
                isPurchasing = false
                showSuccessAlert = true
            } catch {
                isPurchasing = false
                // キャンセルエラーの判定
                if let purchasesError = error as? RevenueCat.ErrorCode, purchasesError == .purchaseCancelledError {
                    // キャンセル時は何もしない
                } else {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func restore() {
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                try await purchaseManager.restorePurchases()
                isPurchasing = false
                if purchaseManager.isPro {
                    showSuccessAlert = true
                } else {
                    errorMessage = "復元可能な購入が見つかりませんでした"
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.brandPurple)
                .frame(width: 30)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}
