import Foundation

public enum MarkdownOutline {
    private struct CodeFence {
        let marker: Character
        let length: Int
    }

    public static func parse(_ content: String) -> [NativeOutlineItem] {
        var usedSlugs = [String: Int]()
        var activeFence: CodeFence?
        return content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line in
                if let fence = activeFence {
                    if closesFence(line, fence: fence) {
                        activeFence = nil
                    }
                    return nil
                }

                if let fence = codeFence(from: line) {
                    activeFence = fence
                    return nil
                }

                return parseHeading(line, usedSlugs: &usedSlugs)
            }
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

    private static func codeFence(from line: Substring) -> CodeFence? {
        var index = line.startIndex
        var spaces = 0
        while index < line.endIndex, line[index] == " ", spaces < 4 {
            spaces += 1
            line.formIndex(after: &index)
        }
        guard spaces <= 3, index < line.endIndex, line[index] != " " else { return nil }

        let marker = line[index]
        guard marker == "`" || marker == "~" else { return nil }

        var length = 0
        while index < line.endIndex, line[index] == marker {
            length += 1
            line.formIndex(after: &index)
        }

        guard length >= 3 else { return nil }
        return CodeFence(marker: marker, length: length)
    }

    private static func closesFence(_ line: Substring, fence: CodeFence) -> Bool {
        var index = line.startIndex
        var spaces = 0
        while index < line.endIndex, line[index] == " ", spaces < 4 {
            spaces += 1
            line.formIndex(after: &index)
        }
        guard spaces <= 3, index < line.endIndex, line[index] != " " else { return false }

        var length = 0
        while index < line.endIndex, line[index] == fence.marker {
            length += 1
            line.formIndex(after: &index)
        }

        guard length >= fence.length else { return false }
        return line[index...].allSatisfy { $0 == " " || $0 == "\t" }
    }
}
