import XCTest
@testable import MdreviewCore

final class MenuTextTests: XCTestCase {
    func testChineseMenuTitles() {
        XCTAssertEqual(MenuText.openFile, "打开文件...")
        XCTAssertEqual(MenuText.openFolder, "打开文件夹...")
        XCTAssertEqual(MenuText.openFolderInNewWindow, "在新窗口中打开文件夹...")
        XCTAssertEqual(MenuText.reloadCurrentDocument, "重新载入当前文档")
        XCTAssertEqual(MenuText.quit, "退出 mdreview")
    }
}
