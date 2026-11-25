import Foundation
import Security
import GTMAppAuth

/// Automatic reads never prompt. Explicit sign-in/recovery may ask macOS to authorize
/// this application, while retaining the existing Keychain ACL and secure storage.
final class NoninteractiveKeychainHelper: NSObject, GTMAppAuth.KeychainHelper {
    private static let interactionLock = NSRecursiveLock()
    let accountName = "OAuth"
    let keychainAttributes: Set<GTMAppAuth.KeychainAttribute>
    private let base: any GTMAppAuth.KeychainHelper
    let allowsUserInteraction: Bool

    convenience init(keychainAttributes: Set<GTMAppAuth.KeychainAttribute>) {
        self.init(keychainAttributes: keychainAttributes, allowsUserInteraction: false)
    }

    init(keychainAttributes: Set<GTMAppAuth.KeychainAttribute>, allowsUserInteraction: Bool) {
        self.allowsUserInteraction = allowsUserInteraction
        self.keychainAttributes = keychainAttributes
        base = GTMAppAuth.KeychainStore(itemName: "", keychainAttributes: keychainAttributes).keychainHelper
        super.init()
    }

    func keychainQuery(forService service: String) -> [String: Any] {
        var query = base.keychainQuery(forService: service)
        query[kSecUseAuthenticationUI as String] = allowsUserInteraction ? kSecUseAuthenticationUIAllow : kSecUseAuthenticationUIFail
        return query
    }

    func passwordData(forService service: String) throws -> Data {
        guard !service.isEmpty else { throw GTMAppAuth.KeychainStore.Error.noService }
        var query = keychainQuery(forService: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = try withInteractionDisabled { SecItemCopyMatching(query as CFDictionary, &result) }
        guard status != errSecItemNotFound else {
            throw GTMAppAuth.KeychainStore.Error.passwordNotFound(forItemName: service)
        }
        guard status == errSecSuccess else { throw GTMAppAuth.KeychainStore.Error.unhandled(status: status) }
        guard let data = result as? Data else {
            throw GTMAppAuth.KeychainStore.Error.unexpectedPasswordData(forItemName: service)
        }
        return data
    }

    func password(forService service: String) throws -> String {
        guard let value = String(data: try passwordData(forService: service), encoding: .utf8) else {
            throw GTMAppAuth.KeychainStore.Error.unexpectedPasswordData(forItemName: service)
        }
        return value
    }

    func setPassword(_ password: String, forService service: String) throws {
        try setPassword(data: Data(password.utf8), forService: service, accessibility: nil)
    }

    func setPassword(_ password: String, forService service: String, accessibility: CFTypeRef) throws {
        try setPassword(data: Data(password.utf8), forService: service, accessibility: accessibility)
    }

    func setPassword(data: Data, forService service: String, accessibility: CFTypeRef?) throws {
        guard !service.isEmpty else { throw GTMAppAuth.KeychainStore.Error.noService }
        let query = keychainQuery(forService: service)
        var attributes: [String: Any] = [kSecValueData as String: data]
        if let accessibility { attributes[kSecAttrAccessible as String] = accessibility }
        // Atualiza no lugar: não apaga/recria a ACL a cada renovação do token.
        let status = try withInteractionDisabled {
            let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updated == errSecItemNotFound else { return updated }
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            return SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw GTMAppAuth.KeychainStore.Error.unhandled(status: status) }
    }

    func removePassword(forService service: String) throws {
        guard !service.isEmpty else { throw GTMAppAuth.KeychainStore.Error.noService }
        let status = try withInteractionDisabled { SecItemDelete(keychainQuery(forService: service) as CFDictionary) }
        guard status != errSecItemNotFound else {
            throw GTMAppAuth.KeychainStore.Error.failedToDeletePasswordBecauseItemNotFound(itemName: service)
        }
        guard status == errSecSuccess else { throw GTMAppAuth.KeychainStore.Error.unhandled(status: status) }
    }

    /// O Chaves legado ignora os controles novos de UI (Apple FB16959400).
    /// O bloqueio é síncrono e escopado; restaura a flag mesmo quando a operação falha.
    func withInteractionDisabled<T>(_ operation: () throws -> T) throws -> T {
        Self.interactionLock.lock()
        defer { Self.interactionLock.unlock() }
        guard keychainAttributes.contains(.useFileBasedKeychain) else { return try operation() }
        var previous: DarwinBoolean = false
        let readStatus = SecKeychainGetUserInteractionAllowed(&previous)
        guard readStatus == errSecSuccess else { throw GTMAppAuth.KeychainStore.Error.unhandled(status: readStatus) }
        let setStatus = SecKeychainSetUserInteractionAllowed(allowsUserInteraction)
        guard setStatus == errSecSuccess else { throw GTMAppAuth.KeychainStore.Error.unhandled(status: setStatus) }
        defer { _ = SecKeychainSetUserInteractionAllowed(previous.boolValue) }
        return try operation()
    }
}
