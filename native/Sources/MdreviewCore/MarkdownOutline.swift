import Foundation

public enum MarkdownOutline {
    public static func parse(_ content: String) -> [NativeOutlineItem] {
        content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap(parseHeading)
    }

    private static func parseHeading(_ line: Substring) -> NativeOutlineItem? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let remainder = line.dropFirst(hashes.count)
        guard remainder.first == " " else { return nil }
        let text = remainder.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return NativeOutlineItem(id: slugify(text), text: text, depth: hashes.count)
    }

    private static func slugify(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
