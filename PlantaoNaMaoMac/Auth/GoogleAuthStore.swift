import AppKit
import Combine
import Foundation
import AppAuth
import GTMAppAuth
import Security

@MainActor
final class GoogleAuthStore: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var displayName = ""
    @Published private(set) var email = ""
    @Published private(set) var photoURL = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var credentialNotice: String?

    var subject: String? { profile?.subject }

    // The traditional Mac keychain uses the creating app's ACL, without restricted entitlements.
    private let credentialLocation = SessionCredentialLocation()
    private var credentialStore: GTMAppAuth.KeychainStore { sessionStore() }
    @Published private(set) var canRestoreSavedSession = false
    private static let signedOutKey = "googleExplicitlySignedOut"
    // This store is used ONLY after an explicit sign-in/recovery button press.
    private var interactiveCredentialStore: GTMAppAuth.KeychainStore { sessionStore(allowInteraction: true) }
    private var authState: OIDAuthState?
    private var authorizationFlow: OIDExternalUserAgentSession?
    private var pendingAuthState: OIDAuthState?
    private var profile: GoogleProfile?
    private var sessionVersion: UInt64 = 0

    init() {
        displayName = UserDefaults.standard.string(forKey: "googleDisplayName") ?? ""
        email = UserDefaults.standard.string(forKey: "googleEmail") ?? ""
        photoURL = UserDefaults.standard.string(forKey: "googlePhotoURL") ?? ""
        #if DEBUG
        if AppLaunch.isUITest {
            isSignedIn = ProcessInfo.processInfo.arguments.contains("--ui-signed-in")
            displayName = isSignedIn ? "Perfil de teste" : ""
            return
        }
        #endif
        isLoading = true
        Task { await restorePreviousSignIn() }
    }

    func signIn() {
        guard !isLoading else { return }
        Task {
            do {
                try await authorize(requiredScopes: [], expectedSubject: nil)
            } catch {
                if let message = Self.message(for: error) { errorMessage = message }
            }
        }
    }

    func restoreSavedSession() {
        guard !isLoading else { return }
        isLoading = true
        Task { await restorePreviousSignIn(allowInteraction: true) }
    }

    func authorizeSessionStorage() {
        guard let state = authState, let profile else { return }
        do { try save(state, profile: profile, allowInteraction: true) }
        catch { credentialNotice = error.localizedDescription }
    }

    func signOut() {
        UserDefaults.standard.set(true, forKey: Self.signedOutKey)
        canRestoreSavedSession = false
        sessionVersion &+= 1
        authorizationFlow?.cancel()
        authorizationFlow = nil
        pendingAuthState = nil
        authState = nil
        profile = nil
        isSignedIn = false
        isLoading = false
        displayName = ""
        email = ""
        photoURL = ""
        errorMessage = nil
        credentialNotice = nil
        do {
            try credentialStore.removeAuthSession()
        } catch {
            if !Self.isMissingCredential(error) {
                errorMessage = "A conta saiu desta sessão, mas o macOS não permitiu remover a sessão salva no Chaves."
            }
        }
        for key in ["googleDisplayName", "googleEmail", "googlePhotoURL"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func handle(_ url: URL) -> Bool {
        guard MacOAuthConfiguration.isCallback(url), let authorizationFlow else { return false }
        do {
            // AppAuth also validates the exact redirect and cryptographically random state.
            try authorizationFlow.resumeExternalUserAgentFlow(url)
            return true
        } catch {
            return false
        }
    }

    /// Token only for the hidden per-user Plantão na Mão sync file in appDataFolder.
    func freshCloudSyncAccessToken() async throws -> String {
        try await freshAccessToken(requiredScopes: [MacOAuthConfiguration.driveAppDataScope])
    }

    private func authorize(requiredScopes: [String], expectedSubject: String?) async throws {
        guard !isLoading else { throw GoogleDriveAuthError.authorizationInProgress }
        guard let window = Self.presentingWindow() else { throw GoogleDriveAuthError.noPresentingWindow }
        isLoading = true
        errorMessage = nil
        sessionVersion &+= 1
        let version = sessionVersion
        defer {
            if sessionVersion == version {
                authorizationFlow = nil
                pendingAuthState = nil
                isLoading = false
            }
        }

        let configuration = OIDServiceConfiguration(
            authorizationEndpoint: MacOAuthConfiguration.authorizationEndpoint,
            tokenEndpoint: MacOAuthConfiguration.tokenEndpoint
        )
        var parameters = ["access_type": "offline", "prompt": "select_account consent"]
        if expectedSubject != nil, !email.isEmpty { parameters["login_hint"] = email }
        // This initializer generates state, nonce, and a fresh S256 PKCE verifier.
        // The public native client has no embedded secret.
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: CrossPlatformOAuth.nativeClientID,
            scopes: MacOAuthConfiguration.requestedScopes,
            redirectURL: MacOAuthConfiguration.redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: parameters
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            authorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: window) { [weak self] state, error in
                // AppAuth dispatches authorization/token callbacks to the main queue.
                // Its Objective-C state stays on our actor; only Void crosses this continuation.
                MainActor.assumeIsolated {
                    guard let self, self.sessionVersion == version else {
                        continuation.resume(throwing: GoogleDriveAuthError.sessionChanged)
                        return
                    }
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let state, state.isAuthorized {
                        self.pendingAuthState = state
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: GoogleDriveAuthError.noGoogleSession)
                    }
                }
            }
        }
        guard sessionVersion == version, let candidate = pendingAuthState else {
            throw GoogleDriveAuthError.sessionChanged
        }
        let token = try await refreshToken(for: candidate, version: version)
        let candidateProfile = try await Self.fetchProfile(accessToken: token)
        guard sessionVersion == version else { throw GoogleDriveAuthError.sessionChanged }
        if let expectedSubject, candidateProfile.subject != expectedSubject {
            throw GoogleDriveAuthError.accountChanged
        }
        guard MacOAuthConfiguration.hasScopes(requiredScopes, granted: candidate.scope) else {
            throw GoogleDriveAuthError.scopeNotGranted
        }
        guard let refresh = candidate.refreshToken, !refresh.isEmpty else {
            throw GoogleDriveAuthError.missingRefreshToken
        }
        if let bound = UserDefaults.standard.string(forKey: "plantao-na-mao.google-account"), bound != candidateProfile.subject {
            throw SyncFailure.wrongAccount
        }
        // A new login is accepted only after it has actually been saved securely.
        try saveNewLogin(candidate, profile: candidateProfile)
        UserDefaults.standard.set(false, forKey: Self.signedOutKey)
        canRestoreSavedSession = false
        authState = candidate
        apply(candidateProfile)
    }

    private func freshAccessToken(requiredScopes: [String]) async throws -> String {
        guard let current = authState, current.isAuthorized else {
            throw GoogleDriveAuthError.noGoogleSession
        }
        if !MacOAuthConfiguration.hasScopes(requiredScopes, granted: current.scope) {
            // Installed clients request their full scope set again. Check account identity before
            // adopting the new state, so cloud sync cannot silently switch Google accounts.
            try await authorize(requiredScopes: requiredScopes, expectedSubject: profile?.subject)
        }
        guard let state = authState else { throw GoogleDriveAuthError.noGoogleSession }
        let token: String
        do {
            token = try await refreshToken(for: state, version: sessionVersion)
        } catch {
            if authState === state, !state.isAuthorized {
                authState = nil
                isSignedIn = false
                errorMessage = GoogleDriveAuthError.noGoogleSession.localizedDescription
            }
            throw error
        }
        guard authState === state else { throw GoogleDriveAuthError.sessionChanged }
        if let profile { persistRefreshedSession(state, profile: profile) }
        return token
    }

    private func refreshToken(for state: OIDAuthState, version: UInt64) async throws -> String {
        let token: String = try await withCheckedThrowingContinuation { continuation in
            state.performAction(freshTokens: { accessToken, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let accessToken, !accessToken.isEmpty {
                    continuation.resume(returning: accessToken)
                } else {
                    continuation.resume(throwing: GoogleDriveAuthError.missingAccessToken)
                }
            })
        }
        guard sessionVersion == version else { throw GoogleDriveAuthError.sessionChanged }
        return token
    }

    private func restorePreviousSignIn(allowInteraction: Bool = false) async {
        let version = sessionVersion
        defer { if sessionVersion == version { isLoading = false } }
        guard !UserDefaults.standard.bool(forKey: Self.signedOutKey) else { return }
        do {
            let stored = try (allowInteraction ? interactiveCredentialStore : credentialStore).retrieveAuthSession()
            let state = stored.authState
            guard state.isAuthorized,
                  state.lastAuthorizationResponse.request.clientID == CrossPlatformOAuth.nativeClientID else {
                canRestoreSavedSession = false
                errorMessage = GoogleDriveAuthError.noGoogleSession.localizedDescription
                return
            }
            let cachedProfile = GoogleProfile(
                subject: stored.userID ?? "", email: stored.userEmail ?? email,
                name: displayName, picture: photoURL, emailVerified: stored.userEmailIsVerified
            )
            authState = state
            canRestoreSavedSession = false
            // Restore the saved identity immediately. A profile/network request is not a login.
            if !cachedProfile.subject.isEmpty, !cachedProfile.email.isEmpty { apply(cachedProfile) }
            do {
                let token = try await refreshToken(for: state, version: version)
                let restoredProfile = try await Self.fetchProfile(accessToken: token)
                guard sessionVersion == version else { return }
                guard cachedProfile.subject.isEmpty || restoredProfile.subject == cachedProfile.subject else {
                    throw GoogleDriveAuthError.accountChanged
                }
                apply(restoredProfile)
                if allowInteraction {
                    do { try save(state, profile: restoredProfile, allowInteraction: true) }
                    catch { credentialNotice = error.localizedDescription }
                } else { persistRefreshedSession(state, profile: restoredProfile) }
            } catch {
                guard sessionVersion == version else { return }
                if state.isAuthorized {
                    // Keep a valid grant through offline starts, transient server/profile errors,
                    // and Keychain write failures. A later Drive request can refresh it again.
                    if !isSignedIn { canRestoreSavedSession = true; errorMessage = Self.message(for: error) }
                } else {
                    authState = nil
                    isSignedIn = false
                    canRestoreSavedSession = false
                    errorMessage = GoogleDriveAuthError.noGoogleSession.localizedDescription
                }
            }
        } catch {
            guard sessionVersion == version else { return }
            if Self.requiresKeychainAuthorization(error) {
                canRestoreSavedSession = true
                errorMessage = "Não foi possível acessar a sessão salva nesta versão. Clique no Google para entrar novamente."
            } else if !Self.isMissingCredential(error) {
                errorMessage = GoogleDriveAuthError.keychainUnavailable.localizedDescription
            } else { canRestoreSavedSession = false }
        }
    }

    private func save(_ state: OIDAuthState, profile: GoogleProfile, allowInteraction: Bool = false) throws {
        do {
            try persist(state, profile: profile, store: sessionStore(allowInteraction: allowInteraction))
        } catch { throw GoogleDriveAuthError.keychainUnavailable }
    }

    private func sessionStore(allowInteraction: Bool = false, service: String? = nil) -> GTMAppAuth.KeychainStore {
        GTMAppAuth.KeychainStore(itemName: service ?? credentialLocation.service,
            keychainHelper: NoninteractiveKeychainHelper(keychainAttributes: [.useFileBasedKeychain],
                                                        allowsUserInteraction: allowInteraction))
    }

    private func persist(_ state: OIDAuthState, profile: GoogleProfile, store: GTMAppAuth.KeychainStore) throws {
        try store.save(authSession: GTMAppAuth.AuthSession(
            authState: state, serviceProvider: "Google", userID: profile.subject,
            userEmail: profile.email, userEmailIsVerified: profile.emailVerified == true ? "true" : "false"
        ))
        let persisted = try store.retrieveAuthSession()
        guard persisted.userID == profile.subject, persisted.authState.isAuthorized else {
            throw GoogleDriveAuthError.keychainUnavailable
        }
        credentialNotice = nil
    }

    private func saveNewLogin(_ state: OIDAuthState, profile: GoogleProfile) throws {
        do {
            do { try persist(state, profile: profile, store: credentialStore) }
            catch {
                guard Self.requiresKeychainAuthorization(error) else { throw error }
                try credentialLocation.replaceInaccessibleCredential { service in
                    try persist(state, profile: profile, store: sessionStore(allowInteraction: true, service: service))
                }
            }
        } catch { throw GoogleDriveAuthError.keychainUnavailable }
    }

    private func persistRefreshedSession(_ state: OIDAuthState, profile: GoogleProfile) {
        do { try save(state, profile: profile) }
        catch {
            // The previously saved grant stays intact; never silently treat a NEW login as persistent.
            credentialNotice = "Autorize o Chaves para atualizar sua sessão salva."
        }
    }

    private func apply(_ profile: GoogleProfile) {
        guard UserDefaults.standard.string(forKey: "plantao-na-mao.google-account").map({ $0 == profile.subject }) ?? true else {
            isSignedIn = false
            errorMessage = SyncFailure.wrongAccount.localizedDescription
            return
        }
        UserDefaults.standard.set(profile.subject, forKey: "plantao-na-mao.google-account")
        self.profile = profile
        displayName = profile.name ?? ""
        email = profile.email
        photoURL = profile.picture ?? ""
        isSignedIn = true
        errorMessage = nil
        UserDefaults.standard.set(displayName, forKey: "googleDisplayName")
        UserDefaults.standard.set(email, forKey: "googleEmail")
        UserDefaults.standard.set(photoURL, forKey: "googlePhotoURL")
    }

    nonisolated private static func fetchProfile(accessToken: String) async throws -> GoogleProfile {
        var request = URLRequest(url: MacOAuthConfiguration.userInfoEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw GoogleDriveAuthError.profileUnavailable }
        guard response.statusCode != 401 else { throw GoogleDriveAuthError.noGoogleSession }
        guard response.statusCode == 200 else { throw GoogleDriveAuthError.profileUnavailable }
        let profile = try JSONDecoder().decode(GoogleProfile.self, from: data)
        guard !profile.subject.isEmpty, !profile.email.isEmpty else { throw GoogleDriveAuthError.profileUnavailable }
        return profile
    }

    private static func presentingWindow() -> NSWindow? {
        NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first(where: { $0.isVisible && $0.canBecomeKey })
    }

    nonisolated private static func isMissingCredential(_ error: Error) -> Bool {
        guard let error = error as? GTMAppAuth.KeychainStore.Error else { return false }
        switch error {
        case .passwordNotFound, .failedToDeletePasswordBecauseItemNotFound:
            return true
        case .unhandled(let status):
            return status == -25300 // errSecItemNotFound
        default:
            return false
        }
    }

    nonisolated private static func requiresKeychainAuthorization(_ error: Error) -> Bool {
        guard case GTMAppAuth.KeychainStore.Error.unhandled(let status) = error else { return false }
        return [errSecInteractionNotAllowed, errSecInteractionRequired, errSecAuthFailed,
                errSecUserCanceled, errSecDuplicateItem].contains(status)
    }

    nonisolated private static func isNetworkError(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSURLErrorDomain ||
            (error.domain == OIDGeneralErrorDomain && error.code == -5)
    }

    nonisolated private static func message(for error: Error) -> String? {
        if let error = error as? GoogleDriveAuthError, error == .sessionChanged { return nil }
        if error is CancellationError { return nil }
        let error = error as NSError
        if error.domain == OIDGeneralErrorDomain, [-3, -4].contains(error.code) { return nil }
        if error.domain == OIDOAuthAuthorizationErrorDomain, error.code == -4 { return nil }
        if error.domain == OIDOAuthTokenErrorDomain { return GoogleDriveAuthError.noGoogleSession.localizedDescription }
        return error.localizedDescription
    }
}

private struct GoogleProfile: Decodable, Sendable {
    let subject: String
    let email: String
    let name: String?
    let picture: String?
    let emailVerified: Bool?

    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case email, name, picture
        case emailVerified = "email_verified"
    }
}

enum GoogleDriveAuthError: LocalizedError, Equatable {
    case noGoogleSession
    case noPresentingWindow
    case scopeNotGranted
    case missingAccessToken
    case missingRefreshToken
    case keychainUnavailable
    case authorizationInProgress
    case sessionChanged
    case accountChanged
    case profileUnavailable

    var errorDescription: String? {
        switch self {
        case .noGoogleSession:
            return "Sua sessão do Google expirou. Entre novamente no Plantão na Mão."
        case .noPresentingWindow:
            return "Não foi possível abrir a autorização do Google Drive."
        case .scopeNotGranted:
            return "O acesso necessário ao Google Drive não foi autorizado. Tente entrar novamente e permitir esse acesso."
        case .missingAccessToken:
            return "O Google não forneceu um token de acesso válido."
        case .missingRefreshToken:
            return "O Google não forneceu autorização para manter a sessão. Tente entrar novamente e confirme o acesso."
        case .keychainUnavailable:
            return "O macOS não permitiu salvar ou ler sua sessão no Chaves. Autorize o acesso ao Chaves e tente novamente."
        case .authorizationInProgress:
            return "Uma autorização do Google já está em andamento. Conclua a janela de login e tente novamente."
        case .sessionChanged:
            return "A sessão foi encerrada."
        case .accountChanged:
            return "Use a mesma conta Google já conectada. Para trocar de conta, saia primeiro no perfil."
        case .profileUnavailable:
            return "Não foi possível carregar seu perfil do Google. Verifique a conexão e tente novamente."
        }
    }
}
