import Foundation

/// A successful upload acknowledges exactly that snapshot, never edits made in flight.
struct SyncCheckpoint {
    private let defaults: UserDefaults
    private let key = "plantao-na-mao.google-uploaded-snapshot.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func needsUpload(_ snapshot: SyncSnapshot) -> Bool {
        guard let data = defaults.data(forKey: key),
              let uploaded = try? JSONDecoder().decode(SyncSnapshot.self, from: data).validated() else { return true }
        return uploaded != SyncMerge.combine([snapshot])
    }
    func acknowledge(_ snapshot: SyncSnapshot) throws {
        defaults.set(try JSONEncoder().encode(SyncMerge.combine([snapshot])), forKey: key)
    }
}
