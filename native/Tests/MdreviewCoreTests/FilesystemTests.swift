import Foundation
import XCTest
@testable import MdreviewCore

final class FilesystemTests: XCTestCase {
    func makeFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mdreview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Root".write(to: root.appendingPathComponent("readme.MD"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
        try "# Guide".write(to: root.appendingPathComponent("docs/guide.markdown"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try "# Ignored".write(to: root.appendingPathComponent("node_modules/ignored.md"), atomically: true, encoding: .utf8)
        try "plain".write(to: root.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        return root
    }

    func testMarkdownTreeSkipsHeavyDirectories() throws {
        let tree = try MarkdownTree.scan(root: makeFixture())
        let encoded = String(describing: tree)
        XCTAssertTrue(encoded.contains("readme.MD"))
        XCTAssertTrue(encoded.contains("guide.markdown"))
        XCTAssertFalse(encoded.contains("ignored.md"))
        XCTAssertFalse(encoded.contains("notes.txt"))
    }

    func testDefaultDocumentPrefersRootReadme() throws {
        let tree = try MarkdownTree.scan(root: makeFixture())
        XCTAssertEqual(MarkdownTree.defaultDocument(in: tree), "readme.MD")
    }

    func testPathValidationRejectsTraversal() throws {
        let root = try makeFixture().resolvingSymlinksInPath()
        let outside = root.deletingLastPathComponent().appendingPathComponent("outside.md")
        try "# Outside".write(to: outside, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try PathValidation.realPath(inside: root, relativePath: "../outside.md"))
    }

    func testResourceAuthorizerAllowsSiblingImageAndRejectsEscape() throws {
        let root = try makeFixture().resolvingSymlinksInPath()
        try "image".write(to: root.appendingPathComponent("logo.png"), atomically: true, encoding: .utf8)
        let document = root.appendingPathComponent("readme.MD")
        let allowed = try ResourceAuthorizer(root: root).resolve(resource: "logo.png", from: document)
        XCTAssertEqual(allowed.lastPathComponent, "logo.png")
        XCTAssertThrowsError(try ResourceAuthorizer(root: root).resolve(resource: "../secret.png", from: document))
    }

    func testResourceAuthorizerAllowsAbsoluteImageInsideRoot() throws {
        let root = try makeFixture().resolvingSymlinksInPath()
        let image = root.appendingPathComponent("docs/diagram.png")
        try "image".write(to: image, atomically: true, encoding: .utf8)
        let document = root.appendingPathComponent("docs/guide.markdown")

        let allowed = try ResourceAuthorizer(root: root).resolve(resource: image.path, from: document)
        let outsideImage = root.deletingLastPathComponent().appendingPathComponent("secret.png")
        try "secret".write(to: outsideImage, atomically: true, encoding: .utf8)

        XCTAssertEqual(allowed.path, image.path)
        XCTAssertThrowsError(
            try ResourceAuthorizer(root: root).resolve(
                resource: outsideImage.path,
                from: document
            )
        )
    }

    func testResourceAuthorizerTreatsLeadingSlashAsRootRelativeFallback() throws {
        let root = try makeFixture().resolvingSymlinksInPath()
        let image = root.appendingPathComponent("docs/diagram.png")
        try "image".write(to: image, atomically: true, encoding: .utf8)
        let document = root.appendingPathComponent("readme.MD")

        let allowed = try ResourceAuthorizer(root: root).resolve(resource: "/docs/diagram.png", from: document)

        XCTAssertEqual(allowed.path, image.path)
    }
}
