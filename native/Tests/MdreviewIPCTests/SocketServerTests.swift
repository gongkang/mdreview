import Darwin
import Foundation
import XCTest
@testable import MdreviewCore
@testable import MdreviewIPC

final class SocketServerTests: XCTestCase {
    func testResponseEncodingMatchesCliContract() throws {
        let response = OpenResponse(accepted: true, action: .focused, message: "已聚焦")
        let data = try SocketCodec.encode(response)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"accepted":true,"action":"focused","message":"已聚焦"}"# + "\n")
    }

    func testSocketServerReceivesRequestAndReplies() throws {
        let socketPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("mdreview-ipc-\(UUID().uuidString).sock")
            .path
        let server = try SocketServer(socketPath: socketPath) { request in
            XCTAssertEqual(request.kind, .openFile)
            XCTAssertEqual(request.path, "/tmp/README.md")
            return OpenResponse(accepted: true, action: .opened, message: "已打开")
        }
        try server.start()
        defer { server.stop() }

        let client = try connectUnixSocket(path: socketPath)
        defer { close(client) }
        let request = #"{"kind":"openFile","path":"/tmp/README.md","newWindow":false}"# + "\n"
        request.withCString { pointer in
            _ = Darwin.write(client, pointer, strlen(pointer))
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = Darwin.read(client, &buffer, buffer.count)
        XCTAssertGreaterThan(count, 0)
        let received = String(data: Data(buffer.prefix(count)), encoding: .utf8)
        XCTAssertEqual(received, #"{"accepted":true,"action":"opened","message":"已打开"}"# + "\n")
    }

    private func connectUnixSocket(path: String) throws -> CInt {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var address = try SocketServer.makeAddress(path: path)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result != 0 {
            close(fd)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return fd
    }
}
