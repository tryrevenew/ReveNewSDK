import Foundation
import Security

final class KeychainManager {
    private let userIdKey = "com.revenew.userId"
    
    /// Returns (userId, isFirstLaunch) tuple
    func getOrCreateUserId() -> (userId: String, isFirstLaunch: Bool) {
        if let existingId = retrieveUserId() {
            return (existingId, false)
        }
        
        // Generate a new UUID if none exists - this means it's first launch
        let newId = UUID().uuidString
        saveUserId(newId)
        return (newId, true)
    }
    
    private func saveUserId(_ userId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdKey,
            kSecValueData as String: userId.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Then add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("Error saving to Keychain: \(status)")
            return
        }
    }
    
    private func retrieveUserId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: userIdKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let userId = String(data: data, encoding: .utf8) {
            return userId
        }
        
        return nil
    }
} 