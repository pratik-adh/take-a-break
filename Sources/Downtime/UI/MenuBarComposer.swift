import AppKit

/// Builds a status item button's title as a single attributed string with
/// the icon inlined as a text attachment, rather than relying on
/// `NSButton`'s separate image+title layout — that combination doesn't
/// reliably vertically center the two against each other at menu bar sizes,
/// which becomes obvious once two status items sit side by side.
enum MenuBarComposer {
    static func attributedTitle(icon: NSImage, text: String, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let attachment = NSTextAttachment()
        attachment.image = icon
        let imageSize = icon.size
        // A text attachment's default bounds sit its bottom on the text
        // baseline; nudge it up so its vertical center lines up with the
        // surrounding text's cap-height center instead of riding high.
        attachment.bounds = CGRect(x: 0,
                                    y: (font.capHeight - imageSize.height) / 2,
                                    width: imageSize.width,
                                    height: imageSize.height)
        result.append(NSAttributedString(attachment: attachment))

        if !text.isEmpty {
            result.append(NSAttributedString(string: " " + text, attributes: [.font: font]))
        }
        return result
    }
}
