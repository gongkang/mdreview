import Foundation

public enum OpenRequestKind: String, Codable, Equatable, Sendable {
    case openFile
    case openDirectory
}

public struct OpenRequest: Codable, Equatable, Sendable {
    public let kind: OpenRequestKind
    public let path: String
    public let newWindow: Bool

    public init(kind: OpenRequestKind, path: String, newWindow: Bool) {
        self.kind = kind
        self.path = path
        self.newWindow = newWindow
    }
}

public enum OpenResponseAction: String, Codable, Equatable, Sendable {
    case opened
    case focused
    case rejected
}

public struct OpenResponse: Codable, Equatable, Sendable {
    public let accepted: Bool
    public let action: OpenResponseAction
    public let message: String

    public init(accepted: Bool, action: OpenResponseAction, message: String) {
        self.accepted = accepted
        self.action = action
        self.message = message
    }
}
