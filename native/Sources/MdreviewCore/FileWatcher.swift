import Darwin
import Foundation

public final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var descriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    public init(url: URL, onChange: @escaping () -> Void) throws {
        self.url = url
        self.onChange = onChange
    }

    public func start() {
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        self.source = source
        source.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
