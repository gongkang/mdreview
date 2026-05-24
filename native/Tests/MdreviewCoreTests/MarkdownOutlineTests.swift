import XCTest
@testable import MdreviewCore

final class MarkdownOutlineTests: XCTestCase {
    func testParsesMarkdownHeadingsForNativeOutline() {
        let items = MarkdownOutline.parse("""
        # Title
        paragraph
        ## Usage
        #### Deep
        #NoSpace
        """)

        XCTAssertEqual(items, [
            NativeOutlineItem(id: "title", text: "Title", depth: 1),
            NativeOutlineItem(id: "usage", text: "Usage", depth: 2),
            NativeOutlineItem(id: "deep", text: "Deep", depth: 4)
        ])
    }

    func testParsesNonLatinHeadingsWithUniqueStableIDs() {
        let items = MarkdownOutline.parse("""
        # mdreview
        ## 使用
        ## 开发
        ## 使用
        """)

        XCTAssertEqual(items, [
            NativeOutlineItem(id: "mdreview", text: "mdreview", depth: 1),
            NativeOutlineItem(id: "使用", text: "使用", depth: 2),
            NativeOutlineItem(id: "开发", text: "开发", depth: 2),
            NativeOutlineItem(id: "使用-1", text: "使用", depth: 2)
        ])
    }

    func testIgnoresHeadingsInsideFencedCodeBlocks() {
        let items = MarkdownOutline.parse("""
        # Visible

        ~~~markdown
        # Hidden
        ## Usage
        ```bash
        mdreview README.md
        ```
        ~~~

        ## Also Visible
        """)

        XCTAssertEqual(items, [
            NativeOutlineItem(id: "visible", text: "Visible", depth: 1),
            NativeOutlineItem(id: "also-visible", text: "Also Visible", depth: 2)
        ])
    }
}
