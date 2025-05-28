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

        let productInfo = ProductInfo(
            currencyCode: product.priceFormatStyle.currencyCode,
            price: product.price,
            priceFormatted: product.displayPrice,
            kind: product.type.rawValue,
            isSandbox: isSandbox,
            appName: appName,
            storeFront: storeFront
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
