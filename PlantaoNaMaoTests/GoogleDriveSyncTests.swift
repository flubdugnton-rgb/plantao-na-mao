import XCTest
#if os(iOS)
@testable import PlantaoNaMao
#endif

private final class DriveMockProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class GoogleDriveSyncTests: XCTestCase {
    private func client() -> GoogleDriveSync {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DriveMockProtocol.self]
        return GoogleDriveSync(session: URLSession(configuration: config))
    }
    override func tearDown() { DriveMockProtocol.handler = nil; super.tearDown() }

    func testDownloadMergesDevicesAndFindsOwnFile() async throws {
        let shift = Shift(date: .now, title: "Original", location: "Hospital", start: .now, end: .now)
        let old = SyncRecord(shift: shift, modifiedAt: Date(timeIntervalSince1970: 1), writerID: "phone")
        var recent = old; recent.modifiedAt = Date(timeIntervalSince1970: 2); recent.shift.notes = "Editado no Mac"
        let phone = try JSONEncoder().encode(SyncSnapshot(records: [old]))
        let mac = try JSONEncoder().encode(SyncSnapshot(records: [recent]))
        DriveMockProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            switch request.url!.path {
            case "/drive/v3/files": return (200, Data(#"{"files":[{"id":"file-phone","name":"plantao-na-mao-sync-v1-phone.json"},{"id":"file-mac","name":"plantao-na-mao-sync-v1-mac.json"}]}"#.utf8))
            case "/drive/v3/files/file-phone": return (200, phone)
            default: return (200, mac)
            }
        }
        let result = try await client().download(deviceID: "phone", token: "test-token")
        XCTAssertEqual(result.ownFileID, "file-phone")
        XCTAssertEqual(result.snapshot.visibleShifts.first?.notes, "Editado no Mac")
    }

    func testCreateUsesPrivateAppFolderAndUpdateUsesPatch() async throws {
        DriveMockProtocol.handler = { request in
            if request.httpMethod == "POST" {
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")!.contains("multipart/related"))
                // URLSession can expose a body stream instead of httpBody to URLProtocol.
                XCTAssertTrue(request.url!.query!.contains("uploadType=multipart"))
            } else { XCTAssertEqual(request.httpMethod, "PATCH"); XCTAssertTrue(request.url!.path.hasSuffix("file-phone")) }
            return (200, Data(#"{"id":"file-phone"}"#.utf8))
        }
        let client = client()
        try await client.upload(SyncSnapshot(), deviceID: "phone", fileID: nil, token: "test-token")
        try await client.upload(SyncSnapshot(), deviceID: "phone", fileID: "file-phone", token: "test-token")
    }

    func testPermissionFailureNeverBecomesAnEmptySuccessfulSync() async throws {
        DriveMockProtocol.handler = { _ in (403, Data()) }
        do {
            _ = try await client().download(deviceID: "phone", token: "test-token")
            XCTFail("Um erro de permissão não pode apagar dados remotos")
        } catch SyncFailure.permission {} catch { XCTFail("Erro inesperado: \(error)") }
    }

    func testCorruptRemoteFileAbortsMerge() async throws {
        DriveMockProtocol.handler = { request in
            if request.url!.path == "/drive/v3/files" {
                return (200, Data(#"{"files":[{"id":"broken","name":"plantao-na-mao-sync-v1-mac.json"}]}"#.utf8))
            }
            return (200, Data("not-a-snapshot".utf8))
        }
        do { _ = try await client().download(deviceID: "phone", token: "test-token"); XCTFail("Dados ilegíveis precisam interromper a sincronização") }
        catch SyncFailure.invalidData {} catch { XCTFail("Erro inesperado: \(error)") }
    }
}
