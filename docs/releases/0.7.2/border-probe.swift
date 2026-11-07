import AppKit
let root = URL(fileURLWithPath: "/Users/mindw/Documents/Projects/Weather")
func measurements(_ name: String) throws -> [String: Any] {
    let data = try Data(contentsOf: root.appendingPathComponent("branding/\(name)"))
    let image = NSBitmapImageRep(data: data)!
    func white(_ x: Int, _ y: Int) -> Bool {
        let c = image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        return c.alphaComponent > 0.9 && c.redComponent > 0.9 && c.greenComponent > 0.9 && c.blueComponent > 0.9
    }
    let w = image.pixelsWide, h = image.pixelsHigh
    var count = 0, whiteCount = 0, interiorWhites = 0
    for x in stride(from: 0, to: w, by: 4) {
        for y in [0, 16, h - 17, h - 1] { count += 1; if white(x,y) { whiteCount += 1 } }
    }
    for y in stride(from: 0, to: h, by: 4) {
        for x in [0, 16, w - 17, w - 1] { count += 1; if white(x,y) { whiteCount += 1 } }
    }
    for x in stride(from: w/4, to: 3*w/4, by: 8) {
        for y in stride(from: h/4, to: 3*h/4, by: 8) { if white(x,y) { interiorWhites += 1 } }
    }
    return ["size": [w,h], "borderSamples": count, "whiteBorderSamples": whiteCount, "interiorWhiteSamples": interiorWhites]
}
let old = try measurements("window-weather-logo-v1.png")
let new = try measurements("window-weather-logo-v2.png")
let passed = (old["whiteBorderSamples"] as! Int) > 0 && (new["whiteBorderSamples"] as! Int) == 0
    && (new["interiorWhiteSamples"] as! Int) > 0
let report: [String: Any] = ["passed": passed, "original": old, "updated": new,
    "scope": "Sampled opaque white outer margins and retained interior whites; visual composition is reviewed separately."]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("docs/releases/0.7.2/border-validation.json"))
print(report)
precondition(passed)
