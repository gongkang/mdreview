import AppKit

@MainActor
final class SidebarRowButton: NSButton {
    enum RowKind {
        case file
        case outline
    }

    private static let outlineTextColor = NSColor(
        calibratedRed: 0.12,
        green: 0.14,
        blue: 0.17,
        alpha: 1
    )

    let depth: Int
    private let kind: RowKind
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var isActive: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, identifier: String, depth: Int, isActive: Bool, kind: RowKind, target: AnyObject?, action: Selector) {
        self.depth = depth
        self.isActive = isActive
        self.kind = kind
        super.init(frame: .zero)
        self.title = title
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        alignment = .left
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
        return NSSize(width: max(96, base.width + CGFloat(depth * 14) + 24), height: 24)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let next = NSTrackingArea(rect: bounds, options: options, owner: self)
        addTrackingArea(next)
        trackingArea = next
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    private func updateAppearance() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = backgroundColor.cgColor
        contentTintColor = textColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: fontForRow,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private var backgroundColor: NSColor {
        if isActive {
            return NSColor.separatorColor.withAlphaComponent(0.08)
        }
        if isHovered {
            return NSColor.separatorColor.withAlphaComponent(0.05)
        }
        return .clear
    }

    private var textColor: NSColor {
        if isActive {
            return .labelColor
        }
        if kind == .outline {
            return Self.outlineTextColor
        }
        return .secondaryLabelColor
    }

    private var fontForRow: NSFont {
        if kind == .outline && depth == 0 {
            return .systemFont(ofSize: 13, weight: .medium)
        }
        return .systemFont(ofSize: 13, weight: .regular)
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingMiddle
        style.firstLineHeadIndent = CGFloat(depth * 14)
        style.headIndent = CGFloat(depth * 14)
        return style
    }
}
