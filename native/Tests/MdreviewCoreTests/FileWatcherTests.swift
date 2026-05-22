import Foundation
import XCTest
@testable import MdreviewCore

final class FileWatcherTests: XCTestCase {
    func testWatcherReportsChange() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-watch-\(UUID().uuidString).md")
        try "# One".write(to: file, atomically: true, encoding: .utf8)
        let expectation = expectation(description: "file changed")
        let watcher = try FileWatcher(url: file) {
            expectation.fulfill()
        }
        watcher.start()
        try "# Two".write(to: file, atomically: true, encoding: .utf8)
        wait(for: [expectation], timeout: 2)
        watcher.stop()
    }
}
