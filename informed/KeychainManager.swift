import Foundation
import Security

// MARK: - Keychain Manager

/// Manages secure storage of sensitive data like session IDs using the iOS Keychain
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - Keys
    
    private let sessionIdKey = "com.jacob.informed.sessionId"
    
    // MARK: - Session ID Methods
    
    /// Saves the session ID securely to the Keychain
    /// - Parameter sessionId: The session ID to store
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func saveSessionId(_ sessionId: String) -> Bool {
        let data = Data(sessionId.utf8)
        
        // First, delete any existing session ID
        deleteSessionId()
        
        // Create query dictionary for saving
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionIdKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Session ID saved to Keychain")
            return true
        } else {
            print("❌ Failed to save session ID to Keychain: \(status)")
            return false
        }
    }
    
    /// Retrieves the session ID from the Keychain
    /// - Returns: The session ID if found, nil otherwise
    func getSessionId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionIdKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let sessionId = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("❌ Failed to retrieve session ID from Keychain: \(status)")
            }
            return nil
        }
        
        return sessionId
    }
    
    /// Deletes the session ID from the Keychain
    /// - Returns: True if successful or if item didn't exist, false otherwise
    @discardableResult
    func deleteSessionId() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: sessionIdKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            if status == errSecSuccess {
                print("✅ Session ID deleted from Keychain")
            }
            return true
        } else {
            print("❌ Failed to delete session ID from Keychain: \(status)")
            return false
        }
    }
    
    /// Checks if a session ID exists in the Keychain
    /// - Returns: True if a session ID exists, false otherwise
    func hasSessionId() -> Bool {
        return getSessionId() != nil
    }
}
