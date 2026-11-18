import SwiftUI
import Combine
import GoogleSignIn

@MainActor
final class GoogleSyncController: ObservableObject {
    @Published private(set) var displayName: String?
    @Published private(set) var hasDriveAccess = false
    @Published private(set) var isConnecting = false
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSync: Date?
    @Published private(set) var errorMessage: String?
    @Published var automatic: Bool {
        didSet {
            defaults.set(automatic, forKey: "plantao-na-mao.google-auto")
            if automatic { requestSync() } else { debounce?.cancel(); resyncRequested = false }
        }
    }
    private let scope = "https://www.googleapis.com/auth/drive.appdata"
    private let defaults: UserDefaults
    private let checkpoint: SyncCheckpoint
    private var active = true
    private let drive = GoogleDriveSync()
    private weak var store: ShiftStore?
    private var changes: AnyCancellable?
    private var debounce: Task<Void, Never>?
    private var generation = UUID()
    private var resyncRequested = false
    private var didStart = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        checkpoint = SyncCheckpoint(defaults: defaults)
        automatic = defaults.bool(forKey: "plantao-na-mao.google-auto")
        let stamp = defaults.double(forKey: "plantao-na-mao.google-last-sync")
        lastSync = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }
    func start(store: ShiftStore) async {
        guard !didStart else { return }; didStart = true; self.store = store
        changes = store.$revision.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.scheduleAfterEdit() }
        }
        guard !AppLaunch.isUITest else { return }
        configure()
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            do {
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                try accept(user)
            } catch { errorMessage = "Reconecte sua conta Google para retomar a sincronização. Seus plantões continuam no aparelho." }
        }
        await resume()
    }
    func connect() async {
        guard !isConnecting, let presenter = Self.presenter() else { return }
        isConnecting = true; errorMessage = nil
        defer { isConnecting = false }
        configure()
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: nil, additionalScopes: [scope])
            try accept(result.user)
            guard hasDriveAccess else { throw SyncFailure.permission }
            automatic = true
            await syncNow()
        } catch {
            if (error as NSError).code != -5 { errorMessage = error.localizedDescription }
        }
    }
    func disconnect() {
        generation = UUID(); automatic = false
        GIDSignIn.sharedInstance.signOut()
        displayName = nil; hasDriveAccess = false; errorMessage = nil
        // Local records and their account binding remain intact.
    }
    func resume() async {
        active = true
        await syncIfChanged()
    }
    func pause() { active = false; debounce?.cancel() }
    private func syncIfChanged() async {
        guard active, automatic, let store, checkpoint.needsUpload(store.snapshot) else { return }
        await syncNow()
    }
    func syncNow() async {
        guard let store, store.canWrite, displayName != nil, hasDriveAccess else { return }
        guard !isSyncing else { resyncRequested = true; return }
        debounce?.cancel()
        resyncRequested = false
        isSyncing = true; errorMessage = nil
        let ticket = generation
        defer {
            isSyncing = false
            let retry = resyncRequested
            resyncRequested = false
            if retry && automatic { scheduleAfterEdit() }
        }
        do {
            guard let current = GIDSignIn.sharedInstance.currentUser else { throw SyncFailure.notConnected }
            let user = try await current.refreshTokensIfNeeded()
            try verifyAccount(user)
            let token = user.accessToken.tokenString
            let remote = try await drive.download(deviceID: store.deviceID, token: token)
            guard generation == ticket, displayName != nil else { return }
            try store.mergeRemote(remote.snapshot)
            // Include any edits made while the remote files were being downloaded.
            let revision = store.revision
            let outgoing = store.snapshot
            try await drive.upload(outgoing, deviceID: store.deviceID, fileID: remote.ownFileID, token: token)
            guard generation == ticket else { return }
            try checkpoint.acknowledge(outgoing)
            lastSync = Date()
            defaults.set(lastSync?.timeIntervalSince1970, forKey: "plantao-na-mao.google-last-sync")
            if store.revision != revision { resyncRequested = true }
        } catch {
            guard generation == ticket else { return }
            errorMessage = error is URLError ? SyncFailure.serviceUnavailable.localizedDescription : error.localizedDescription
        }
    }
    private func configure() {
        if let client = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !client.isEmpty {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: client)
        }
    }
    private func verifyAccount(_ user: GIDGoogleUser) throws {
        guard let id = user.userID else { throw SyncFailure.notConnected }
        if let bound = defaults.string(forKey: "plantao-na-mao.google-account"), bound != id {
            throw SyncFailure.wrongAccount
        }
    }
    private func accept(_ user: GIDGoogleUser) throws {
        do { try verifyAccount(user) }
        catch { GIDSignIn.sharedInstance.signOut(); displayName = nil; hasDriveAccess = false; throw error }
        defaults.set(user.userID, forKey: "plantao-na-mao.google-account")
        let name = user.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        displayName = name.isEmpty ? "Conta Google conectada" : name
        hasDriveAccess = user.grantedScopes?.contains(scope) == true
        if !hasDriveAccess { errorMessage = "Autorize a pasta privada do app para sincronizar seus plantões." }
        generation = UUID()
    }
    private func requestSync() { Task { [weak self] in await self?.syncIfChanged() } }
    private func scheduleAfterEdit() {
        guard automatic, active else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.requestSync()
        }
    }
    private static func presenter() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        var presenter = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let next = presenter?.presentedViewController { presenter = next }
        return presenter
    }
}

