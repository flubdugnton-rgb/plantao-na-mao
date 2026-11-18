import Foundation

struct SyncRecord: Codable, Equatable {
    var shift: Shift
    var modifiedAt: Date
    var writerID: String
}

struct SyncDeletion: Codable, Equatable {
    var id: UUID
    var modifiedAt: Date
    var writerID: String
}

struct SyncSnapshot: Codable, Equatable {
    var schemaVersion = 2
    var records: [SyncRecord] = []
    var deletions: [SyncDeletion] = []
    var visibleShifts: [Shift] { records.map(\.shift).sorted { $0.interval.start < $1.interval.start } }

    func validated() throws -> SyncSnapshot {
        guard schemaVersion == 1 || schemaVersion == 2 else { throw SyncFailure.newerVersion }
        return SyncMerge.combine([self])
    }
}

enum SyncFailure: LocalizedError {
    case newerVersion, invalidData, permission, serviceUnavailable, wrongAccount, notConnected
    var errorDescription: String? {
        switch self {
        case .newerVersion: return "Há dados de uma versão mais recente. Atualize o app para sincronizar. Seus registros locais foram preservados."
        case .invalidData: return "Não foi possível ler os dados do Google. Seus registros locais foram preservados."
        case .permission: return "O Google não autorizou o acesso à pasta do app. Reconecte sua conta. Se o problema continuar, verifique se a API Google Drive está ativada no projeto do app."
        case .serviceUnavailable: return "O Google está indisponível ou sem conexão. Seus dados estão salvos no aparelho; as alterações pendentes serão reenviadas ao voltar ao app ou tocar em Sincronizar agora."
        case .wrongAccount: return "Estes registros estão vinculados a outra conta Google. Conecte a conta usada anteriormente para manter seus dados separados."
        case .notConnected: return "Conecte sua conta Google em Ajustes para sincronizar."
        }
    }
}

enum SyncMerge {
    // The same Foundation-only format can be reused by the future macOS app.
    // Each device owns its own Drive file; devices never overwrite one another's files.
    static func combine(_ snapshots: [SyncSnapshot]) -> SyncSnapshot {
        var records: [UUID: SyncRecord] = [:]
        var deleted: [UUID: SyncDeletion] = [:]
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        func wins(_ candidate: SyncRecord, over current: SyncRecord) -> Bool {
            if candidate.modifiedAt != current.modifiedAt { return candidate.modifiedAt > current.modifiedAt }
            if candidate.writerID != current.writerID { return candidate.writerID > current.writerID }
            let a = (try? encoder.encode(candidate.shift)) ?? Data()
            let b = (try? encoder.encode(current.shift)) ?? Data()
            return b.lexicographicallyPrecedes(a)
        }
        for snapshot in snapshots {
            for record in snapshot.records {
                if let current = records[record.shift.id], !wins(record, over: current) { continue }
                records[record.shift.id] = record
            }
            for deletion in snapshot.deletions {
                if let current = deleted[deletion.id] {
                    if current.modifiedAt > deletion.modifiedAt { continue }
                    if current.modifiedAt == deletion.modifiedAt && current.writerID >= deletion.writerID { continue }
                }
                deleted[deletion.id] = deletion
            }
        }
        for (id, deletion) in deleted {
            if let record = records[id], deletion.modifiedAt >= record.modifiedAt { records.removeValue(forKey: id) }
        }
        return SyncSnapshot(records: records.values.sorted { $0.shift.id.uuidString < $1.shift.id.uuidString },
                            deletions: deleted.values.sorted { $0.id.uuidString < $1.id.uuidString })
    }
}

