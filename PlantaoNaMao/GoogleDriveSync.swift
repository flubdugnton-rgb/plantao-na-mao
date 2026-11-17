import Foundation

struct DriveRemoteState {
    var snapshot: SyncSnapshot
    var ownFileID: String?
}

actor GoogleDriveSync {
    private let session: URLSession
    private static let prefix = "plantao-na-mao-sync-v1-"
    init(session: URLSession = .shared) { self.session = session }

    func download(deviceID: String, token: String) async throws -> DriveRemoteState {
        struct FileList: Decodable {
            struct File: Decodable { let id: String; let name: String }
            let files: [File]
            let nextPageToken: String?
        }
        var snapshots: [SyncSnapshot] = []
        var ownFiles: [String] = []
        var nextPage: String?
        repeat {
            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
            components.queryItems = [URLQueryItem(name: "spaces", value: "appDataFolder"),
                                     URLQueryItem(name: "q", value: "name contains '\(Self.prefix)'"),
                                     URLQueryItem(name: "fields", value: "nextPageToken,files(id,name)"),
                                     URLQueryItem(name: "pageSize", value: "1000")]
            if let nextPage { components.queryItems?.append(URLQueryItem(name: "pageToken", value: nextPage)) }
            let list = try JSONDecoder().decode(FileList.self, from: await request(url: components.url!, token: token))
            for file in list.files where file.name.hasPrefix(Self.prefix) && file.name.hasSuffix(".json") {
                let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media")!
                let data = try await request(url: url, token: token)
                let snapshot: SyncSnapshot
                do { snapshot = try JSONDecoder().decode(SyncSnapshot.self, from: data).validated() }
                catch let error as SyncFailure { throw error }
                catch { throw SyncFailure.invalidData }
                snapshots.append(snapshot)
                if file.name == Self.prefix + deviceID + ".json" { ownFiles.append(file.id) }
            }
            nextPage = list.nextPageToken
        } while nextPage != nil
        return DriveRemoteState(snapshot: SyncMerge.combine(snapshots), ownFileID: ownFiles.sorted().first)
    }

    func upload(_ snapshot: SyncSnapshot, deviceID: String, fileID: String?, token: String) async throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot.validated())
        if let fileID {
            let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files/\(fileID)?uploadType=media")!
            _ = try await request(url: url, token: token, method: "PATCH", body: data, contentType: "application/json")
        } else {
            let boundary = "PlantaoBoundary-" + UUID().uuidString
            let metadata: [String: Any] = ["name": Self.prefix + deviceID + ".json", "parents": ["appDataFolder"], "mimeType": "application/json"]
            var body = Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8)
            body.append(try JSONSerialization.data(withJSONObject: metadata))
            body.append(Data("\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".utf8))
            body.append(data); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
            let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id")!
            _ = try await request(url: url, token: token, method: "POST", body: body, contentType: "multipart/related; boundary=\(boundary)")
        }
    }

    private func request(url: URL, token: String, method: String = "GET", body: Data? = nil, contentType: String? = nil) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = method; request.httpBody = body
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw SyncFailure.serviceUnavailable }
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 || response.statusCode == 403 { throw SyncFailure.permission }
            throw SyncFailure.serviceUnavailable
        }
        return data
    }
}
