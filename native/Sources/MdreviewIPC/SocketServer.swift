import Darwin
import Foundation
import MdreviewCore

public enum SocketCodec {
    public static func decodeRequest(_ data: Data) throws -> OpenRequest {
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return try JSONDecoder().decode(OpenRequest.self, from: Data(trimmed.utf8))
    }

    public static func encode(_ response: OpenResponse) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(response)
        data.append(0x0A)
        return data
    }
}

public enum SocketServerError: Error {
    case pathTooLong
    case socketFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
}

public final class SocketServer: @unchecked Sendable {
    private let socketPath: String
    private let handler: (OpenRequest) -> OpenResponse
    private let queue = DispatchQueue(label: "mdreview.ipc.socket")
    private var serverFD: CInt = -1
    private var isRunning = false

    public init(socketPath: String, handler: @escaping (OpenRequest) -> OpenResponse) throws {
        self.socketPath = socketPath
        self.handler = handler
    }

    public func start() throws {
        if FileManager.default.fileExists(atPath: socketPath) {
            try FileManager.default.removeItem(atPath: socketPath)
        }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketServerError.socketFailed(errno) }
        serverFD = fd

        var address = try Self.makeAddress(path: socketPath)
        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            serverFD = -1
            throw SocketServerError.bindFailed(errno)
        }
        chmod(socketPath, S_IRUSR | S_IWUSR)

        guard listen(fd, SOMAXCONN) == 0 else {
            close(fd)
            serverFD = -1
            throw SocketServerError.listenFailed(errno)
        }
        isRunning = true
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        isRunning = false
        if serverFD >= 0 {
            shutdown(serverFD, SHUT_RDWR)
            close(serverFD)
            serverFD = -1
        }
        try? FileManager.default.removeItem(atPath: socketPath)
    }

    public static func makeAddress(path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < maxPathLength else { throw SocketServerError.pathTooLong }
        _ = path.withCString { source in
            withUnsafeMutablePointer(to: &address.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { destination in
                    strncpy(destination, source, maxPathLength - 1)
                }
            }
        }
        return address
    }

    private func acceptLoop() {
        while isRunning {
            let clientFD = accept(serverFD, nil, nil)
            if clientFD < 0 {
                if isRunning { continue }
                return
            }
            handle(clientFD: clientFD)
        }
    }

    private func handle(clientFD: CInt) {
        defer { close(clientFD) }
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let count = Darwin.read(clientFD, &buffer, buffer.count)
        guard count > 0 else { return }
        let data = Data(buffer.prefix(count))
        let response: OpenResponse
        do {
            let request = try SocketCodec.decodeRequest(data)
            response = handler(request)
        } catch {
            response = OpenResponse(accepted: false, action: .rejected, message: "无法解析打开请求")
        }
        guard let encoded = try? SocketCodec.encode(response) else { return }
        encoded.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            _ = Darwin.write(clientFD, base, rawBuffer.count)
        }
    }
}
