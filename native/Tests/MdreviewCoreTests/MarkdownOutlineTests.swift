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
}
