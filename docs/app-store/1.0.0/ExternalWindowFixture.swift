import AppKit

// Separate process: a sandboxed product must see another app's geometry, not only its own fixtures.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let visible = NSScreen.screens.last!.visibleFrame
let window = NSWindow(contentRect: NSRect(x: visible.minX + 80, y: visible.minY + 100, width: 400, height: 240),
                      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
window.title = "WindowWeather external geometry fixture"
window.isReleasedWhenClosed = false
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.orderFrontRegardless()
let metadata: [String: Any] = ["windowID": window.windowNumber, "pid": ProcessInfo.processInfo.processIdentifier]
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]).write(to: output)
app.run()
