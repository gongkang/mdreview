import AppKit

@MainActor
final class DocumentTabButton: NSButton {
    var isActive: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, identifier: String, isActive: Bool, target: AnyObject?, action: Selector) {
        self.isActive = isActive
        super.init(frame: .zero)
        self.title = title
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        alignment = .center
        lineBreakMode = .byTruncatingMiddle
        focusRingType = .default
        setAccessibilityLabel(title)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        return NSSize(width: max(72, base.width + 18), height: 30)
    }

    private func updateAppearance() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingMiddle
        var attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: isActive ? .medium : .regular),
            .foregroundColor: isActive ? NSColor.labelColor : NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ]
        if isActive {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.underlineColor] = NSColor.separatorColor
        }
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }
}
