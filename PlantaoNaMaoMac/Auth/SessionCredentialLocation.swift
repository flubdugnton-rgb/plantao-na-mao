import Foundation

/// Stores only the Keychain service name. Tokens remain in the macOS Keychain.
@MainActor
final class SessionCredentialLocation {
    static let legacyService = "com.plantaonamao.macos.google-oauth"
    private static let preferenceKey = "googleSessionKeychainService"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var service: String {
        let saved = defaults.string(forKey: Self.preferenceKey) ?? ""
        return saved.hasPrefix(Self.legacyService + ".") ? saved : Self.legacyService
    }

    /// A new OAuth grant can be saved without touching an older build's protected item.
    /// Adopt the new location only after both writing and reading it have succeeded.
    func replaceInaccessibleCredential(writeAndVerify: (String) throws -> Void) throws {
        let next = Self.legacyService + "." + UUID().uuidString
        try writeAndVerify(next)
        defaults.set(next, forKey: Self.preferenceKey)
    }
}
