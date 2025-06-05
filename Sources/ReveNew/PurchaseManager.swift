//
//  File.swift
//  ReveNew
//
//  Created by Pietro Messineo on 5/22/25.
//

import Foundation
import StoreKit
import Combine

@MainActor
public final class PurchaseManager: ObservableObject {
    @Published public var products: [Product] = []
    @Published public var isLoading: Bool = false
    @Published public var error: String?
    @Published public var isSubscribed: Bool = false
    
    private var updates: Task<Void, Never>? = nil
    private let userDefaults = UserDefaults.standard
    private let lastLoggedTransactionKey = "com.revenew.lastLoggedTransaction"
    
    private let reveNew: PurchaseObserver
    
    private var productsIds: [String] = []
    
    /// Initialize Purchase Manager, a wrapper of StoreKit 2 to handle purchase for you.
    /// - Parameters:
    ///   - appName: A String that represents the name of your app to gather analytics later
    ///   - host: A String of the IP address where the service is hosted
    ///   - port: An Integere of the port where the service is hosted
    ///   - productsIds: An optional array of productsIds of your subscriptions or IAP from App Store. If you fetch this via RemoteConfig or other services later, please call func setProductsIds(productsIds: [String]) to set your products ids
    public init(appName: String, host: String, port: Int, productsIds: [String]?) {
        self.reveNew = PurchaseObserver(appName: appName, host: host, port: port)
        self.updates = observeTransactionUpdates()
        
        if let productsIds {
            setProductsIds(productsIds)
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    public func setProductsIds(_ productsIds: [String]) {
        self.productsIds = productsIds
        
        Task {
            await hasActiveSubscription()
        }
    }
    
    /// Take care of fetching IAP and/or subscriptions
    /// from AppStoreConnect.
    /// Publish an Array of Product
    public func fetchProducts() async {
        do {
            isLoading = true
            products = try await Product.products(for: productsIds)
            isLoading = false
        } catch {
            print("Error fetching products \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    // TODO: - Maybe a state machine with purchaseStatus ?
    /// Take care of the purchase flow for both IAP and Subscriptions
    /// - Parameter product: the storekit Product you are trying to purchase
    /// that was fetched previously by the fetchProducts() method
    /// - Returns: An optional Product in case the purchase was successful
    public func purchaseProduct(_ product: Product) async throws -> Product? {
        do {
            isLoading = true
            let result = try await product.purchase()
            
            switch result {
            case let .success(.verified(transaction)):
                // Successful purhcase
                await transaction.finish()
                
                // Determine if this is a trial purchase
                let (isTrial, trialPeriod) = determineTrialStatus(transaction: transaction, product: product)
                
                // Log Purchase with trial information
                reveNew.logTrialOrConversion(transaction, product, isTrial: isTrial, trialPeriod: trialPeriod)
                userDefaults.set(String(transaction.id), forKey: lastLoggedTransactionKey)
                
                isLoading = false
                
                return product
            case let .success(.unverified(transaction , error)):
                // Successful purchase but transaction/receipt can't be verified
                // Could be a jailbroken phone
                print("Unverified purchase. Might be jailbroken. Error: \(error)")
                isLoading = false
                
                // Determine if this is a trial purchase
                let (isTrial, trialPeriod) = determineTrialStatus(transaction: transaction, product: product)
                
                // Log Purchase with trial information
                reveNew.logTrialOrConversion(transaction, product, isTrial: isTrial, trialPeriod: trialPeriod)
                userDefaults.set(String(transaction.id), forKey: lastLoggedTransactionKey)
                
                return product
            case .pending:
                // Transaction waiting on SCA (Strong Customer Authentication) or
                // approval from Ask to Buy
                isLoading = false
                return nil
            case .userCancelled:
                // ^^^
                print("User Cancelled!")
                isLoading = false
                
                return nil
            @unknown default:
                print("Failed to purchase the product!")
                isLoading = false
                error = "Failed to purchase the product."
                
                return nil
            }
        } catch {
            print("Failed to purchase the product!")
            isLoading = false
            self.error = "Something went wrong, \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Take care of restoring a purchase (ex. subscription or NON consumable purchase)
    /// - Returns: A Bool in case the restore purchase was successful or not
    public func restorePurchase() async -> Bool {
        isLoading = true
        
        // Sync transactions with App Store
        let isSynced = (try? await AppStore.sync()) != nil
        if !isSynced {
            isLoading = false
            return false
        }
        
        // Verify if the user has an active entitlement
        var hasActivePurchase = false
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if productsIds.contains(transaction.productID) {
                hasActivePurchase = true
                break
            }
        }
        
        isLoading = false
        return hasActivePurchase
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [unowned self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                
                // Find the corresponding product for this transaction
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    // Check if this is a subscription transaction
                    if let subscriptionStatus = await transaction.subscriptionStatus,
                       subscriptionStatus.state != .revoked {
                        // Get the transaction ID and convert to string for storage
                        let transactionId = String(transaction.id)
                        
                        // Get the last logged transaction ID
                        let lastLoggedId = userDefaults.string(forKey: lastLoggedTransactionKey)
                        
                        // Only log if this is a new transaction
                        if lastLoggedId != transactionId {
                            // Determine if this is a trial start or conversion
                            let (isTrial, trialPeriod) = determineTrialStatus(transaction: transaction, product: product)
                            
                            // Log with trial-specific information
                            reveNew.logTrialOrConversion(transaction, product, isTrial: isTrial, trialPeriod: trialPeriod)
                            
                            // Store this transaction ID as the last logged
                            userDefaults.set(transactionId, forKey: lastLoggedTransactionKey)
                            
                            // Update subscription status
                            await hasActiveSubscription()
                        }
                    }
                }
                
                await transaction.finish()
            }
        }
    }
    
    private func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                print("Insert product \(transaction.productID)")
            } else {
                print("Remove product \(transaction.productID)")
            }
        }
    }
    
    /// Checks if the user has any active subscription
    /// - Returns: A Boolean indicating whether the user has an active subscription
    private func hasActiveSubscription() async {
        // First sync with App Store to ensure we have the latest transaction status
        guard (try? await AppStore.sync()) != nil else {
            isSubscribed = false
            return
        }
        
        // Check current entitlements for any active subscription
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            // Check if the transaction is for one of our products
            guard productsIds.contains(transaction.productID) else { continue }
            
            // Check if the transaction is still valid (not expired or revoked)
            if transaction.revocationDate == nil {
                if let expirationDate = transaction.expirationDate {
                    // For subscriptions, check if it hasn't expired
                    if expirationDate > Date() {
                        isSubscribed = true
                        return
                    }
                } else {
                    // For non-subscription purchases that don't expire
                    isSubscribed = true
                    return
                }
            }
        }
        
        isSubscribed = false
    }
    
    /// Helper method to determine if a transaction is a trial start or a conversion
    /// - Parameters:
    ///   - transaction: The StoreKit transaction
    ///   - product: The product being purchased
    /// - Returns: A tuple containing (isTrial, trialPeriod)
    private func determineTrialStatus(transaction: Transaction, product: Product) -> (isTrial: Bool, trialPeriod: String?) {
        var isTrial = false
        var trialPeriod: String? = nil
        
        if let subscription = product.subscription,
           let introductoryOffer = subscription.introductoryOffer,
           introductoryOffer.paymentMode == .freeTrial {
            
            // Check if this is the first transaction by looking at the original purchase date
            // If the transaction date is close to the original purchase date, it's likely the first transaction
            let isFirstTransaction = transaction.originalPurchaseDate.timeIntervalSince(transaction.purchaseDate).magnitude < 60 // Within a minute
            
            if isFirstTransaction {
                isTrial = true
                let period = introductoryOffer.period
                trialPeriod = "\(period.value) \(period.unit.localizedDescription)"
            }
        }
        
        return (isTrial, trialPeriod)
    }
}
