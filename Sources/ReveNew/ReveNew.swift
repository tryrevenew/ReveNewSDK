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
}
