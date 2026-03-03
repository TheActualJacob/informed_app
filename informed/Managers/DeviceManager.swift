//
//  DeviceManager.swift
//  informed
//
//  Provides a stable, per-device UUID that persists across app reinstalls.
//  Stored in the iOS Keychain with ThisDeviceOnly accessibility so it is
//  never synced to iCloud and never migrates to a new device.
//

import Foundation
import Security

enum DeviceManager {

    // MARK: - Public API

    /// A stable device identifier that survives app uninstalls.
    /// Generated once and stored in the Keychain on first access.
    static var deviceId: String {
        if let existing = readFromKeychain() {
            return existing
        }
        let fresh = UUID().uuidString
        writeToKeychain(fresh)
        return fresh
    }

    // MARK: - Keychain helpers

    private static let service = "com.informed.device"
    private static let account = "device_id"

    private static func readFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func writeToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let attributes: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrService:             service,
            kSecAttrAccount:             account,
            kSecValueData:               data,
            // ThisDeviceOnly = not backed up, not synced, not migrated to a new device
            kSecAttrAccessible:          kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        // Remove any stale entry first, then insert fresh
        SecItemDelete(([
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as [CFString: Any]) as CFDictionary)
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
