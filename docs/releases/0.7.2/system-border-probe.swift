import AppKit
let root = URL(fileURLWithPath: "/Users/mindw/Documents/Projects/Weather/docs/releases")
func whiteRimSamples(_ version: String) throws -> Int {
    let image = NSBitmapImageRep(data: try Data(contentsOf: root.appendingPathComponent("\(version)/running-app-icon-128.png")))!
    precondition(image.pixelsWide == 128 && image.pixelsHigh == 128)
    var count = 0
    // Compare the broad rim inside the OS silhouette, away from the white snow.
    for along in stride(from: 32, through: 96, by: 2) {
        for (x,y) in [(16,along),(111,along),(along,16),(along,111)] {
            let c = image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
            if c.alphaComponent > 0.9 && min(c.redComponent, c.greenComponent, c.blueComponent) > 0.9 { count += 1 }
        }
    }
    return count
}
let old = try whiteRimSamples("0.7.1"), new = try whiteRimSamples("0.7.2")
let report: [String: Any] = ["passed": old > 0 && new == 0, "previousWhiteRimSamples": old,
    "updatedWhiteRimSamples": new, "samplesPerIcon": 132,
    "scope": "128px NSRunningApplication icon images from this Mac; samples in the old broad rim, not the snow or thin system highlights."]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("0.7.2/system-border-validation.json"))
print(report)
precondition(old > 0 && new == 0)
