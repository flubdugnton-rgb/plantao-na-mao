import Foundation
import Security
import LocalAuthentication

// Only this app's calendar projection and read receipt are stored here.
// No access-group override: the OS uses the groups granted by the installed signature.
enum WidgetKeychain {
    private static let service = "com.plantaonamao.widget-calendar.v1"
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }
    @discardableResult
    static func write(_ data: Data, account: String) -> OSStatus {
        let search = query(account)
        let changes: [String: Any] = [kSecValueData as String: data,
                                     kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(search as CFDictionary, changes as CFDictionary)
        guard status == errSecItemNotFound else { return status }
        var item = search
        changes.forEach { item[$0.key] = $0.value }
        return SecItemAdd(item as CFDictionary, nil)
    }
    static func read(account: String) -> Data? {
        var search = query(account)
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext(); context.interactionNotAllowed = true
        search[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
    static func save(_ payload: WidgetCalendarPayload) -> OSStatus {
        guard let data = try? JSONEncoder().encode(payload) else { return errSecParam }
        return write(data, account: "calendar")
    }
    static func load() -> WidgetCalendarPayload? {
        guard let data = read(account: "calendar") else { return nil }
        return try? JSONDecoder().decode(WidgetCalendarPayload.self, from: data)
    }
    static func receipt() -> WidgetReadReceipt? {
        guard let data = read(account: "receipt") else { return nil }
        return try? JSONDecoder().decode(WidgetReadReceipt.self, from: data)
    }
    static func acknowledge(_ receipt: WidgetReadReceipt) {
        guard let data = try? JSONEncoder().encode(receipt) else { return }
        write(data, account: "receipt")
    }
}
