# ReveNew SDK

ReveNew is a Swift SDK designed to help you track and manage in-app purchases and app downloads in your iOS applications. It provides a simple interface to log purchases and automatically track unique app installations.

## Features

- Automatic tracking of unique app installations
- In-app purchase logging
- Subscription purchase and renewal tracking
- Persistent device identification across app reinstalls
- Secure storage using Keychain
- Support for both production and sandbox environments

## Requirements

- iOS 16.0+
- Swift 6.1+

## Installation

### Swift Package Manager

Add ReveNew to your project through Xcode:

1. File > Add Packages...
2. Enter the package URL: `https://github.com/yourusername/ReveNew.git`
3. Select the version you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ReveNew.git", from: "1.0.0")
]
```

## Usage

### Initialization

First, initialize the SDK with your app's configuration:

```swift
import ReveNew

let purchaseObserver = PurchaseObserver(
    appName: "YourAppName",
    host: "your-api-host.com",  // e.g., "api.yourserver.com"
    port: 3032                  // Your API port number
)
```

The SDK will automatically:
- Generate a unique identifier for the device
- Log the first app installation (only once per device, persists across reinstalls)

### Logging In-App Purchases

To log an in-app purchase:

```swift
// When a purchase is completed
let transaction: Transaction = ... // StoreKit transaction
let product: Product = ...        // StoreKit product

purchaseObserver.logPurchase(transaction, product)
```

### Setting Up Purchase Management

To handle in-app purchases and subscriptions:

```swift
let productIds = ["com.yourapp.premium", "com.yourapp.subscription"]
let purchaseManager = PurchaseManager(
    appName: "YourAppName",
    host: "your-api-host.com",
    port: 3032,
    productsIds: productIds
)

// Fetch available products
await purchaseManager.fetchProducts()

// Make a purchase
if let product = purchaseManager.products.first {
    try await purchaseManager.purchaseProduct(product)
}

// Restore purchases
let restored = await purchaseManager.restorePurchase()
```

### Subscription Status

The `isSubscribed` property is a `@Published` property, making it perfect for SwiftUI integration:

```swift
struct ContentView: View {
    @StateObject var purchaseManager = PurchaseManager(
        appName: "YourAppName",
        host: "your-api-host.com",
        port: 3032,
        productsIds: ["com.yourapp.subscription"]
    )
    
    var body: some View {
        VStack {
            if purchaseManager.isSubscribed {
                PremiumContentView()
            } else {
                SubscriptionOfferView()
            }
        }
        .task {
            await purchaseManager.fetchProducts()
        }
    }
}
```

You can also use it with Combine if needed:

```swift
purchaseManager.$isSubscribed
    .sink { isSubscribed in
        // Handle subscription status changes
    }
    .store(in: &cancellables)
```

## API Reference

### PurchaseObserver

The main class for logging purchases and installations.

#### Methods

- `init(appName: String, host: String, port: Int)`
  - Initializes the observer and automatically logs first-time installations
  - Parameters:
    - `appName`: Your app's name for filtering and grouping transactions
    - `host`: Your API server's host address
    - `port`: Your API server's port number

- `logPurchase(_ transaction: Transaction, _ product: Product)`
  - Logs a successful purchase
  - Parameters:
    - `transaction`: The StoreKit transaction
    - `product`: The purchased StoreKit product

### PurchaseManager

Handles in-app purchases and subscriptions.

#### Properties

- `products: [Product]` - Available products fetched from App Store Connect
- `isLoading: Bool` - Loading state for async operations
- `error: String?` - Error message if something goes wrong
- `isSubscribed: Bool` - Current subscription status

#### Methods

- `init(appName: String, host: String, port: Int, productsIds: [String])`
  - Initializes the purchase manager
  - Parameters:
    - `appName`: Your app's name
    - `host`: Your API server's host
    - `port`: Your API server's port
    - `productsIds`: Array of product identifiers

- `fetchProducts() async`
  - Fetches available products from App Store Connect

- `purchaseProduct(_ product: Product) async throws -> Product?`
  - Initiates a purchase for the specified product
  - Returns the purchased product if successful

- `restorePurchase() async -> Bool`
  - Restores previous purchases
  - Returns true if restoration was successful

## Server API Endpoints

The SDK communicates with your server using these endpoints:

### Log Purchase
- Endpoint: `/api/v1/log-purchase`
- Method: POST
- Body:
  ```json
  {
    "currencyCode": "USD",
    "price": 4.99,
    "priceFormatted": "$4.99",
    "kind": "autoRenewable",
    "isSandbox": false,
    "appName": "YourApp",
    "storeFront": "US"
  }
  ```

### Log Download
- Endpoint: `/api/v1/log-download`
- Method: POST
- Body:
  ```json
  {
    "userId": "unique-device-id",
    "appName": "YourApp"
  }
  ```

## Security

The SDK uses the iOS Keychain to securely store:
- Unique device identifier
- Installation tracking

This ensures that:
- Device identification persists across app reinstalls
- Each device is counted only once for downloads
- Sensitive data is stored securely

## License

[Your License Here] 