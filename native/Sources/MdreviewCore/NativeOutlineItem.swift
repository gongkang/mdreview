import Foundation

public struct NativeOutlineItem: Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let depth: Int

    public init(id: String, text: String, depth: Int) {
        self.id = id
        self.text = text
        self.depth = depth
    }
}
