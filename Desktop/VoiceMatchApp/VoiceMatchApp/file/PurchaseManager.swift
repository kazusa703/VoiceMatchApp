import Foundation
import RevenueCat
import SwiftUI
import Combine

class PurchaseManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = PurchaseManager()
    
    // アプリ全体で監視する課金ステータス
    @Published var isPro = false
    // 購入可能な商品リスト
    @Published var offerings: Offerings?
    
    override init() {
        super.init()
    }
    
    // VoiceMatchApp.swift から呼ばれる初期化メソッド
    func configure(apiKey: String) {
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        
        // 初期設定完了後に最新の情報を取得
        updateCustomerInfo()
        fetchOfferings()
    }
    
    // 顧客情報の更新とPro判定
    func updateCustomerInfo() {
        Purchases.shared.getCustomerInfo { [weak self] (info, error) in
            guard let self = self else { return }
            if let info = info {
                self.updateProStatus(from: info)
            }
        }
    }
    
    // RevenueCatから商品情報（Offerings）を取得
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
    
    // 購入処理の実行
    func purchase(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        updateProStatus(from: result.customerInfo)
    }
    
    // 購入履歴の復元（機種変更時など）
    func restorePurchases() {
        Task {
            do {
                let info = try await Purchases.shared.restorePurchases()
                updateProStatus(from: info)
            } catch {
                print("復元エラー: \(error)")
            }
        }
    }
    
    // デバッグ用：擬似的にProを有効化
    func purchasePro() {
        DispatchQueue.main.async {
            self.isPro = true
        }
    }
    
    // RevenueCatのエンタイトルメントID（例: "pro"）を元にステータスを更新
    private func updateProStatus(from info: CustomerInfo) {
        let isProActive = info.entitlements["pro"]?.isActive == true
        
        DispatchQueue.main.async {
            self.isPro = isProActive
        }
    }
    
    // MARK: - PurchasesDelegate
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateProStatus(from: customerInfo)
    }
}
