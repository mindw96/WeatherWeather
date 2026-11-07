import AppKit

let target = "/Users/mindw/Applications/WindowWeather.app"
let output = URL(fileURLWithPath: "/Users/mindw/Documents/Projects/Weather/docs/releases/0.7.1")
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "org.windowweather.app")
    .first { $0.bundleURL?.path == target }
let icons: [(String, NSImage?)] = [
    ("finder-resolved-icon", NSWorkspace.shared.icon(forFile: target)),
    ("running-app-icon", app?.icon)
]
var exported: [String] = []
for (name, icon) in icons {
    guard let icon else { fatalError("No system icon: \(name)") }
    for size in [32, 128] {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "\(name)-\(size).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        exported.append(name)
    }
}
let report: [String: Any] = ["installedPath": target, "running": app != nil,
    "pid": app?.processIdentifier ?? 0, "resolvedIconImages": exported,
    "scope": "NSWorkspace file icon and NSRunningApplication icon, rendered offscreen; not a desktop screenshot."]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("system-icon-check.json"))
print(String(decoding: data, as: UTF8.self))
