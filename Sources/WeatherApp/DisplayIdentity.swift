import AppKit
import ColorSync

enum DisplayIdentity {
    static func key(for screen: NSScreen) -> String {
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        if let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        // shortcut: UUID-less displays use a session ID; add hardware matching if persistence is needed.
        return "display-\(number)"
    }
}
