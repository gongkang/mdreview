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
    private static let indentUnit: CGFloat = 14
    private static let maximumIndent: CGFloat = 84

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
        lineBreakMode = .byTruncatingTail
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
        return NSSize(width: max(96, base.width + visualIndent + 24), height: 24)
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
            return .systemFont(ofSize: 14, weight: .medium)
        }
        return .systemFont(ofSize: 14, weight: .regular)
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingTail
        style.firstLineHeadIndent = visualIndent
        style.headIndent = visualIndent
        return style
    }

    private var visualIndent: CGFloat {
        min(CGFloat(depth) * Self.indentUnit, Self.maximumIndent)
    }
}

@MainActor
final class SidebarDirectoryRowButton: NSButton {
    private static let indentUnit: CGFloat = 14
    private static let maximumIndent: CGFloat = 84

    let depth: Int
    private let displayTitle: String
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var isExpanded: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String, identifier: String, depth: Int, isExpanded: Bool, target: AnyObject?, action: Selector) {
        self.depth = depth
        self.displayTitle = title
        self.isExpanded = isExpanded
        super.init(frame: .zero)
        self.title = title
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        self.tag = depth
        self.target = target
        self.action = action
        setButtonType(.momentaryChange)
        isBordered = false
        bezelStyle = .regularSquare
        alignment = .left
        lineBreakMode = .byTruncatingTail
        focusRingType = .default
        setAccessibilityLabel(displayTitle)
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
        return NSSize(width: max(96, base.width + visualIndent + 24), height: 24)
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
        attributedTitle = NSAttributedString(
            string: "\(disclosureSymbol) \(displayTitle)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: depth == 0 ? .medium : .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private var disclosureSymbol: String {
        isExpanded ? "▾" : "▸"
    }

    private var backgroundColor: NSColor {
        isHovered ? NSColor.separatorColor.withAlphaComponent(0.05) : .clear
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byTruncatingTail
        style.firstLineHeadIndent = visualIndent
        style.headIndent = visualIndent
        return style
    }

    private var visualIndent: CGFloat {
        min(CGFloat(depth) * Self.indentUnit, Self.maximumIndent)
    }
}
