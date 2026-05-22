import Foundation

public struct MarkdownNode: Codable, Equatable, CustomStringConvertible {
    public enum NodeType: String, Codable { case file, directory }

    public let type: NodeType
    public let name: String
    public let path: String
    public let children: [MarkdownNode]

    public var description: String {
        "\(type.rawValue):\(path):\(children)"
    }

    public init(type: NodeType, name: String, path: String, children: [MarkdownNode]) {
        self.type = type
        self.name = name
        self.path = path
        self.children = children
    }
}

public enum MarkdownTree {
    private static let skipped = Set([".git", "node_modules", "dist", "build"])
    private static let readmeNames = Set(["readme.md", "readme.markdown"])

    public static func scan(root: URL, relativePath: String = "") throws -> [MarkdownNode] {
        let directory = relativePath.isEmpty ? root : root.appendingPathComponent(relativePath)
        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey])
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var nodes: [MarkdownNode] = []
        for entry in entries {
            let name = entry.lastPathComponent
            let childRelative = relativePath.isEmpty ? name : "\(relativePath)/\(name)"
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values.isDirectory == true {
                if skipped.contains(name) { continue }
                let children = try scan(root: root, relativePath: childRelative)
                if !children.isEmpty {
                    nodes.append(MarkdownNode(type: .directory, name: name, path: childRelative, children: children))
                }
            } else if values.isRegularFile == true && PathValidation.isMarkdown(name) {
                nodes.append(MarkdownNode(type: .file, name: name, path: childRelative, children: []))
            }
        }
        return nodes
    }

    public static func flatten(_ nodes: [MarkdownNode]) -> [MarkdownNode] {
        nodes.flatMap { $0.type == .file ? [$0] : flatten($0.children) }
    }

    public static func defaultDocument(in nodes: [MarkdownNode]) -> String? {
        let files = flatten(nodes)
        if let readme = files.first(where: { readmeNames.contains($0.path.lowercased()) }) {
            return readme.path
        }
        return files.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }.first?.path
    }
}
