import StoreKit
import Foundation

@MainActor
public final class PurchaseObserver {
    private let logManager: LogManager
    private let appName: String
    
    /// Take care of initializing the PurchasObserver to log your transactions from your app to your backend
    /// - Parameters:
    ///   - appName: Your App Name for filtering on the client side and group transactions by app
    ///   - host: Your host address where your backend is hosted (ex. 192.168.1.1)
    ///   - port: The port that you opened for the api (ex. 3022)
    public init(appName: String, host: String, port: Int) {
        self.appName = appName
        self.logManager = LogManager(host: host, port: port, appName: appName)
    }
    
    public func logPurchase(_ transaction: Transaction, _ product: Product) {
        Task {
            do {
                try await logManager.logPurchase(transaction: transaction, product: product, appName: appName)
            } catch {
                print("Error logging purchase \(error.localizedDescription)")
            }
        }
    }
    
    /// Log a trial start or trial conversion explicitly
    /// - Parameters:
    ///   - transaction: The StoreKit transaction
    ///   - product: The product being purchased
    ///   - isTrial: Whether this is a trial start (true) or a conversion (false)
    ///   - trialPeriod: The trial period description (e.g. "7 days") if this is a trial start
    public func logTrialOrConversion(_ transaction: Transaction, _ product: Product, isTrial: Bool, trialPeriod: String? = nil) {
        Task {
            do {
                // Create a custom ProductInfo that explicitly sets the trial information
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
                    storeFront: storeFront,
                    isTrial: isTrial,
                    trialPeriod: trialPeriod
                )
                
                let _ = try await logManager.service.logPurchase(productInfo: productInfo)
            } catch {
                print("Error logging trial or conversion: \(error.localizedDescription)")
            }
        }
    }
}
