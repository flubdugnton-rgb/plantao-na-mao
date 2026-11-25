import Combine
import Foundation

/// Uses the iOS wire format, merge rules, deletion markers and per-device Drive files.
@MainActor
final class MacSyncController: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSync: Date?
    @Published var automatic: Bool {
        didSet {
            defaults.set(automatic, forKey: "plantao-na-mao.google-auto")
            if automatic { Task { await resume() } } else { pause() }
        }
    }
    private let defaults: UserDefaults
    private let drive: GoogleDriveSync
    private let checkpoint: SyncCheckpoint
    private weak var store: ShiftStore?
    private weak var auth: GoogleAuthStore?
    private var changes = Set<AnyCancellable>()
    private var debounce: Task<Void, Never>?
    private var polling: Task<Void, Never>?
    private var active = true
    private var started = false
    private var generation = UUID()
    private var resyncRequested = false

    init(defaults: UserDefaults = .standard, drive: GoogleDriveSync = GoogleDriveSync()) {
        self.defaults = defaults; self.drive = drive
        checkpoint = SyncCheckpoint(defaults: defaults)
        automatic = defaults.object(forKey: "plantao-na-mao.google-auto") == nil || defaults.bool(forKey: "plantao-na-mao.google-auto")
        let stamp = defaults.double(forKey: "plantao-na-mao.google-last-sync")
        lastSync = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }
    func start(store: ShiftStore, auth: GoogleAuthStore) async {
        guard !started else { return }; started = true
        self.store = store; self.auth = auth
        guard !AppLaunch.isUITest else { return }
        store.$revision.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.scheduleAfterEdit() }
        }.store(in: &changes)
        auth.$isSignedIn.removeDuplicates().sink { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                self.generation = UUID()
                if connected { await self.resume() } else { self.pause() }
            }
        }.store(in: &changes)
    }
    func resume() async {
        active = true
        guard automatic, !AppLaunch.isUITest else { return }
        startPolling()
        // Always pull when returning to the app, including when this device has no edits.
        await syncNow()
    }
    func pause() {
        active = false
        debounce?.cancel(); polling?.cancel(); polling = nil
    }
    private func startPolling() {
        guard polling == nil, auth?.isSignedIn == true else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 30_000_000_000) } catch { return }
                guard let self, self.active, self.automatic, self.auth?.isSignedIn == true else { return }
                await self.syncNow()
            }
        }
    }
    private func scheduleAfterEdit() {
        guard automatic, active else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            await self?.syncNow()
        }
    }
    func syncNow() async {
        guard let store, store.canWrite, let auth, auth.isSignedIn, let subject = auth.subject else { return }
        guard !isSyncing else { resyncRequested = true; return }
        isSyncing = true; errorMessage = nil; resyncRequested = false
        debounce?.cancel()
        let ticket = generation
        defer {
            isSyncing = false
            if resyncRequested { resyncRequested = false; scheduleAfterEdit() }
        }
        do {
            guard defaults.string(forKey: "plantao-na-mao.google-account") == subject else { throw SyncFailure.wrongAccount }
            let token = try await auth.freshCloudSyncAccessToken()
            let remote = try await drive.download(deviceID: store.deviceID, token: token)
            guard generation == ticket, auth.isSignedIn, auth.subject == subject else { return }
            try store.mergeRemote(remote.snapshot)
            let revision = store.revision, outgoing = store.snapshot
            // Avoid uploading unchanged data on every background pull.
            if checkpoint.needsUpload(outgoing) || remote.ownFileID == nil {
                try await drive.upload(outgoing, deviceID: store.deviceID, fileID: remote.ownFileID, token: token)
                guard generation == ticket, auth.isSignedIn, auth.subject == subject else { return }
                try checkpoint.acknowledge(outgoing)
            }
            lastSync = Date()
            defaults.set(lastSync?.timeIntervalSince1970, forKey: "plantao-na-mao.google-last-sync")
            if store.revision != revision { resyncRequested = true }
        } catch {
            guard generation == ticket else { return }
            errorMessage = error is URLError ? SyncFailure.serviceUnavailable.localizedDescription : error.localizedDescription
        }
    }
}
