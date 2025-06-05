//
//  CloudFlareManager.swift
//  Vision Pal
//
//  Created by Pietro Messineo on 03/03/24.
//

import Foundation
import StoreKit

@MainActor
final class LogManager: ObservableObject {
    let service: LogService
    private let keychainManager = KeychainManager()
    private let appName: String
    
    init(host: String, port: Int, appName: String) {
        self.service = LogService(host: host, port: port)
        self.appName = appName
        
        // Check if this is first launch and log download if needed
        Task {
            await checkAndLogFirstDownload()
        }
    }
    
    /// Log purchase
    func logPurchase(transaction: Transaction, product: Product, appName: String) async throws {
        var storeFront = "-"
        
        if #available(iOS 17.0, *) {
            storeFront = transaction.storefront.countryCode
        }
        
        let isSandbox = transaction.environment != .production
        
        // Determine if this is a trial purchase
        var isTrial = false
        var trialPeriod: String? = nil
        
        if let subscription = product.subscription {
            // Check if product has a trial offer
            if let introductoryOffer = subscription.introductoryOffer,
               introductoryOffer.paymentMode == .freeTrial {
                isTrial = true
                // Format the trial period (e.g., "1 week", "2 months")
                let period = introductoryOffer.period
                trialPeriod = "\(period.value) \(period.unit.localizedDescription)"
            }
        }

        let productInfo = ProductInfo(
            currencyCode: product.priceFormatStyle.currencyCode,
            price: product.price,
            priceFormatted: product.displayPrice,
            kind: product.type.rawValue,
            isSandbox: isSandbox,
            appName: appName,
            storeFront: storeFront,
            isTrial: isTrial,
            trialPeriod: trialPeriod
        )
        
        let _ = try await service.logPurchase(productInfo: productInfo)
    }
    
    private func checkAndLogFirstDownload() async {
        do {
            let (userId, isFirstLaunch) = keychainManager.getOrCreateUserId()
            
            // Only log download if this is the first launch (no existing userId in Keychain)
            if isFirstLaunch {
                let _ = try await service.logDownload(userId: userId, appName: appName)
            }
        } catch {
            print("Error logging first download: \(error.localizedDescription)")
        }
    }
}
