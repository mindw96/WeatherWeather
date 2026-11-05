import Foundation
import CryptoKit

@main struct Benchmark {
    static func fingerprint(_ simulation: WeatherSimulation) -> String {
        var bytes = Data()
        func add(_ value: UInt64) { var v = value.littleEndian; withUnsafeBytes(of: &v) { bytes.append(contentsOf: $0) } }
        func add(_ value: Double) { add(value.bitPattern) }
        add(UInt64(simulation.particles.count))
        for p in simulation.particles {
            for value in [p.x,p.y,p.vx,p.vy,p.size,p.opacity,p.rotation,p.angularVelocity,p.phase] { add(value) }
            add(UInt64(p.variant))
        }
        for p in simulation.piles {
            add(UInt64(p.surfaceID)); add(p.x); add(p.y); add(p.width)
            for h in p.heights { add(h) }
        }
        for p in simulation.splashes { for value in [p.x,p.y,p.vx,p.vy,p.life] { add(value) } }
        for p in simulation.settledParticles {
            add(p.id); add(UInt64(p.surfaceID)); add(UInt64(p.variant))
            for value in [p.position,p.offsetY,p.size,p.rotation,p.life] { add(value) }
        }
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    static func main() throws {
        var rows: [[String: Any]] = []
        for mode in WeatherMode.allCases {
            let simulation = WeatherSimulation(width: 3840, height: 2160, seed: 17)
            simulation.mode = mode
            simulation.intensity = 1
            simulation.wind = 0.15
            let surfaces: [Surface] = (0..<12).map { (index: Int) -> Surface in
                let x = Double(index % 4) * 870.0
                let y = Double(index / 4 + 1) * 650.0
                return Surface(id: UInt32(index + 1), x: x, y: y, width: 850)
            }
            simulation.setSurfaces(surfaces)
            for _ in 0..<900 { simulation.update(deltaTime: 1 / 30.0) }
            let start = ProcessInfo.processInfo.systemUptime
            for frame in 0..<9000 {
                if frame % 6 == 0 { simulation.setSurfaces(surfaces) }
                simulation.update(deltaTime: 1 / 30.0)
            }
            rows.append(["case": mode.rawValue, "seconds": ProcessInfo.processInfo.systemUptime - start, "fingerprint": fingerprint(simulation), "particles": simulation.particles.count])
        }
        let simulation = WeatherSimulation(width: 1920, height: 1080, seed: 39)
        let surfaces = (0..<24).map { index in Surface(id: UInt32(index+1), x: Double(index)*30, y: Double(index)*20, width: 1200) }
        simulation.setSurfaces(surfaces)
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<20000 { simulation.setSurfaces(surfaces) }
        rows.append(["case":"unchangedGeometry24Windows", "seconds": ProcessInfo.processInfo.systemUptime-start, "fingerprint": fingerprint(simulation)])
        let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted,.sortedKeys])
        print(String(data:data,encoding:.utf8)!)
    }
}
