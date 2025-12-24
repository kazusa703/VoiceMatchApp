import Foundation
import RevenueCat
import SwiftUI
import Combine

// NSObject と PurchasesDelegate を継承して、更新を自動検知できるようにします
class PurchaseManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = PurchaseManager()
    
    @Published var isPro = false
    @Published var offerings: Offerings?
    
    override init() {
        super.init()
    }
    
    // ★追加: VoiceMatchApp.swift から呼ばれる初期化メソッド
    func configure(apiKey: String) {
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        
        // 設定完了後に情報を取得
        updateCustomerInfo()
        fetchOfferings()
    }
    
    // 顧客情報の更新（Proかどうかの判定）
    func updateCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let self = self else { return }
            if let info = info {
                self.updateProStatus(from: info)
            }
        }
    }
    
    // 商品情報（Offerings）の取得
    func fetchOfferings() {
        Purchases.shared.getOfferings { [weak self] (offerings, error) in
            guard let self = self else { return }
            if let offerings = offerings {
                DispatchQueue.main.async {
                    self.offerings = offerings
                }
            }
        }
    }
    
    // 購入処理
    func purchase(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        updateProStatus(from: result.customerInfo)
    }
    
    // 復元処理
    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        updateProStatus(from: info)
    }
    
    // ステータスの更新ロジック
    private func updateProStatus(from info: CustomerInfo) {
        // "pro" というエンタイトルメントIDが有効かどうかチェック
        let isProActive = info.entitlements["pro"]?.isActive == true
        
        DispatchQueue.main.async {
            self.isPro = isProActive
        }
    }
    
    // MARK: - PurchasesDelegate
    // RevenueCat側で情報の更新があった時に自動で呼ばれる
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(from: customerInfo)
    }
}
