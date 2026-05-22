import AppKit
import MdreviewCore

@MainActor
final class DocumentTabBar: NSObject {
    let view = NSStackView()
    var onSelectTab: ((UUID) -> Void)?

    override init() {
        super.init()
        view.orientation = .horizontal
        view.alignment = .centerY
        view.spacing = 0
        view.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
    }

    func render(tabs: [DocumentTab], activeTabID: UUID?) {
        view.arrangedSubviews.forEach { subview in
            view.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        for tab in tabs {
            let button = NSButton(title: tab.title, target: self, action: #selector(selectTab(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(tab.id.uuidString)
            button.bezelStyle = tab.id == activeTabID ? .rounded : .texturedRounded
            view.addArrangedSubview(button)
        }
        if tabs.isEmpty {
            view.addArrangedSubview(NSTextField(labelWithString: "未打开文档"))
        }
    }

    @objc private func selectTab(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let id = UUID(uuidString: raw) else { return }
        onSelectTab?(id)
    }
}
