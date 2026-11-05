import AppKit
import Foundation
import WeatherCore

guard CommandLine.arguments.count == 2 else { fatalError("Pass the report output directory") }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let bounds = CGRect(x: 0, y: 0, width: 800, height: 480)
let before = WeatherViewBefore(frame: bounds, seed: 2026)
let after = WeatherView(frame: bounds, seed: 2026)
before.showSnowman = false
after.showSnowman = false
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 480,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
func render(_ view: NSView) -> Data {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.cgContext.saveGState()
    graphics.cgContext.translateBy(x: 0, y: 480)
    graphics.cgContext.scaleBy(x: 1, y: -1)
    view.draw(view.bounds)
    graphics.cgContext.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return Data(bytes: bitmap.bitmapData!, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
}
func measure(_ view: NSView, frames: Int = 80) -> Double {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.cgContext.saveGState()
    graphics.cgContext.translateBy(x: 0, y: 480)
    graphics.cgContext.scaleBy(x: 1, y: -1)
    let start = ProcessInfo.processInfo.systemUptime
    for _ in 0..<frames { autoreleasepool { view.draw(view.bounds) } }
    let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000 / Double(frames)
    graphics.cgContext.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return elapsed
}
func prepare(_ simulation: WeatherSimulation, mode: WeatherMode) {
    simulation.mode = mode
    simulation.intensity = 1
    simulation.wind = 0.4
    simulation.setSurfaces([
        Surface(id: 1, x: 65, y: 270, width: 370),
        Surface(id: 2, x: 460, y: 170, width: 280),
        Surface(id: 0, x: 0, y: 479, width: 800)
    ])
    for _ in 0..<1800 { simulation.update(deltaTime: 1.0 / 30) }
}
var checks: [[String: Any]] = []
var benchmarks: [[String: Any]] = []
for mode in WeatherMode.allCases {
    prepare(before.simulation, mode: mode)
    prepare(after.simulation, mode: mode)
    precondition(before.simulation.particles == after.simulation.particles)
    for hidden in [false, true] {
        let mask = hidden ? WindowGeometry(id: 2, x: 460, y: 170, width: 280, height: 280) : nil
        before.hiddenFocusedWindow = mask
        after.hiddenFocusedWindow = mask
        let oldPixels = render(before)
        let newPixels = render(after)
        guard oldPixels == newPixels else {
            fputs("Pixel mismatch for \(mode), hidden=\(hidden)\n", stderr)
            exit(1)
        }
        checks.append(["mode": mode.rawValue, "focusedWindowHidden": hidden, "byteIdentical": true])
    }
    before.hiddenFocusedWindow = nil
    after.hiddenFocusedWindow = nil
    if mode.isSeasonal {
        _ = measure(before, frames: 10)
        _ = measure(after, frames: 10)
        var oldSamples: [Double] = []
        var newSamples: [Double] = []
        for trial in 0..<7 {
            if trial % 2 == 0 {
                oldSamples.append(measure(before)); newSamples.append(measure(after))
            } else {
                newSamples.append(measure(after)); oldSamples.append(measure(before))
            }
        }
        let oldMedian = oldSamples.sorted()[3], newMedian = newSamples.sorted()[3]
        benchmarks.append(["mode": mode.rawValue,
            "fallingCount": after.simulation.particles.count,
            "settledCount": after.simulation.settledParticles.count,
            "beforeMillisecondsPerFrameMedian": oldMedian,
            "afterMillisecondsPerFrameMedian": newMedian,
            "changePercent": (newMedian / oldMedian - 1) * 100,
            "beforeSamples": oldSamples, "afterSamples": newSamples])
    }
}
let report: [String: Any] = ["pixelChecks": checks, "benchmarks": benchmarks,
    "note": "800x480 offscreen Core Graphics, same deterministic simulation snapshot and per-object transforms; 7 alternating-order trials of 80 frames. This is not whole-app CPU or battery measurement."]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: root.appendingPathComponent("render-comparison.json"))
print(String(data: data, encoding: .utf8)!)
