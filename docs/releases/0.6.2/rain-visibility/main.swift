import AppKit
import WeatherCore

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let bounds = CGRect(x: 0, y: 0, width: 800, height: 480)
let before = WeatherViewBefore(frame: bounds, seed: 2026)
let after = WeatherView(frame: bounds, seed: 2026)
before.showSnowman = false
after.showSnowman = false
func prepare(_ simulation: WeatherSimulation, mode: WeatherMode) {
    simulation.mode = mode
    simulation.intensity = 0.85
    simulation.wind = 0.2
    simulation.setSurfaces([
        Surface(id: 1, x: 65, y: 270, width: 370, cornerRadius: 16),
        Surface(id: 2, x: 460, y: 170, width: 280, cornerRadius: 16),
        Surface(id: 0, x: 0, y: 479, width: 800)
    ])
    for _ in 0..<1800 { simulation.update(deltaTime: 1.0 / 30) }
}
func render(_ view: NSView, background: CGFloat? = nil) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 480,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 800 * 4, bitsPerPixel: 32)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    bitmap.bitmapData!.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.translateBy(x: 0, y: 480)
    context.scaleBy(x: 1, y: -1)
    view.draw(view.bounds)
    if let background {
        context.setBlendMode(.destinationOver)
        context.setFillColor(NSColor(calibratedWhite: background > 0.5 ? 0.94 : 0.18, alpha: 1).cgColor)
        for rect in [CGRect(x: 65, y: 270, width: 370, height: 300), CGRect(x: 460, y: 170, width: 280, height: 310)] {
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil))
            context.fillPath()
        }
        context.setFillColor(NSColor(calibratedWhite: background, alpha: 1).cgColor)
        context.fill(bounds)
    }
    return bitmap
}
func bytes(_ bitmap: NSBitmapImageRep) -> [UInt8] {
    Array(UnsafeBufferPointer(start: bitmap.bitmapData!, count: bitmap.bytesPerRow * bitmap.pixelsHigh))
}
func alphaBytes(_ bitmap: NSBitmapImageRep) -> [UInt8] {
    let b = bytes(bitmap), alpha = bitmap.bitmapFormat.contains(.alphaFirst) ? 0 : 3
    return stride(from: alpha, to: b.count, by: 4).map { b[$0] }
}
func rainColorDistance(_ bitmap: NSBitmapImageRep) -> Double {
    let b = bytes(bitmap), alphaFirst = bitmap.bitmapFormat.contains(.alphaFirst)
    let channels = alphaFirst ? [1, 2, 3] : [0, 1, 2]
    let background = channels.map { Double(b[$0]) }
    var sum = 0.0
    // Above both synthetic windows: falling rain only, with identical particle positions.
    for y in 10..<150 {
        for x in 0..<800 {
            let index = y * bitmap.bytesPerRow + x * 4
            for c in 0..<3 { sum += abs(Double(b[index + channels[c]]) - background[c]) }
        }
    }
    return sum
}
var checks: [String: Bool] = [:]
var samples: [[String: Any]] = []
for mode in WeatherMode.allCases {
    prepare(before.simulation, mode: mode)
    prepare(after.simulation, mode: mode)
    let old = render(before), new = render(after)
    checks["\(mode.rawValue)GeometryAndOpacityUnchanged"] = alphaBytes(old) == alphaBytes(new)
    checks["\(mode.rawValue)ParticleStateUnchanged"] = before.simulation.particles == after.simulation.particles
        && before.simulation.piles == after.simulation.piles && before.simulation.splashes == after.simulation.splashes
        && before.simulation.settledParticles == after.simulation.settledParticles
    if mode != .rain {
        checks["\(mode.rawValue)PixelsUnchanged"] = bytes(old) == bytes(new)
        continue
    }
    for (label, background) in [("light", CGFloat(1)), ("dark", CGFloat(0.08))] {
        let oldBackground = render(before, background: background)
        let newBackground = render(after, background: background)
        let previous = rainColorDistance(oldBackground), current = rainColorDistance(newBackground)
        samples.append(["background": label, "beforeRGBDistance": previous,
                        "afterRGBDistance": current, "ratio": current / previous])
        checks["\(label)RainRemainsVisible"] = previous > 0 && current > 0
        checks["\(label)ContrastRequirement"] = label == "light" ? current > previous * 1.2 : current > previous * 0.75
        try oldBackground.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("rain-\(label)-before.png"))
        try newBackground.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("rain-\(label)-after.png"))
    }
}
let report: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 }, "samples": samples,
    "scope": "Same deterministic scene rendered to 800x480 Core Graphics bitmaps. RGB distance of falling rain pixels on solid backgrounds is a comparison metric, not WCAG contrast or a human perception threshold. No screen capture or performance claim."]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("rain-color-comparison.json"))
print(String(data: try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]), encoding: .utf8)!)
precondition(checks.values.allSatisfy { $0 })
