import Foundation

public enum MarkdownOutline {
    public static func parse(_ content: String) -> [NativeOutlineItem] {
        var usedSlugs = [String: Int]()
        return content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { parseHeading($0, usedSlugs: &usedSlugs) }
    }

    private static func parseHeading(_ line: Substring, usedSlugs: inout [String: Int]) -> NativeOutlineItem? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let remainder = line.dropFirst(hashes.count)
        guard remainder.first == " " else { return nil }
        let text = remainder.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return NativeOutlineItem(id: uniqueSlug(text, usedSlugs: &usedSlugs), text: text, depth: hashes.count)
    }

    private static func uniqueSlug(_ value: String, usedSlugs: inout [String: Int]) -> String {
        let base = slugify(value)
        let count = usedSlugs[base, default: 0]
        usedSlugs[base] = count + 1
        return count == 0 ? base : "\(base)-\(count)"
    }

    private static func slugify(_ value: String) -> String {
        let slug = value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "section" : slug
    }
}
