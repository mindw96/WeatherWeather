import Foundation

@main struct CurvedSurfaceBenchmark {
    static func main() throws {
        let measuredFrames = 3_000
        var samples: [[String: Any]] = []
        var finalCounts: [String: [Int]] = [:]
        for trial in 0..<3 {
            for mode in WeatherMode.allCases {
                for radius in trial % 2 == 0 ? [0.0, 26.0] : [26.0, 0.0] {
                    let simulation = WeatherSimulation(width: 3_840, height: 2_160, seed: 17)
                    simulation.mode = mode
                    simulation.intensity = 1
                    simulation.wind = 0.15
                    let surfaces: [Surface] = (0..<10).map { (index: Int) -> Surface in
                        let x = Double(index % 5) * 700.0
                        let y = Double(index / 5) * 800.0 + 650.0
                        return Surface(id: UInt32(index + 1), x: x, y: y, width: 650, cornerRadius: radius)
                    }
                    simulation.setSurfaces(surfaces)
                    for _ in 0..<900 { simulation.update(deltaTime: 1 / 30.0) }
                    let start = ProcessInfo.processInfo.systemUptime
                    for frame in 0..<measuredFrames {
                        if frame % 6 == 0 { simulation.setSurfaces(surfaces) }
                        simulation.update(deltaTime: 1 / 30.0)
                    }
                    let seconds = ProcessInfo.processInfo.systemUptime - start
                    precondition(simulation.piles.count == 10)
                    precondition(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0.isFinite && $0 >= 0 } })
                    precondition(simulation.particles.count <= WeatherSimulation.maximumParticles)
                    precondition(simulation.settledParticles.count <= WeatherSimulation.maximumSettledParticles)
                    let counts = [simulation.particles.count, simulation.settledParticles.count,
                                  simulation.splashes.count, simulation.piles.reduce(0) { $0 + $1.heights.count }]
                    let key = "\(mode.rawValue):\(radius)"
                    if let previous = finalCounts[key] { precondition(previous == counts) }
                    finalCounts[key] = counts
                    samples.append([
                        "trial": trial + 1, "mode": mode.rawValue, "radius": radius,
                        "seconds": seconds, "millisecondsPerSimulatedFrame": seconds * 1_000 / Double(measuredFrames),
                        "fallingParticles": counts[0], "settledParticles": counts[1],
                        "splashes": counts[2], "totalHeightBins": counts[3]
                    ])
                }
            }
        }
        let result: [String: Any] = [
            "scope": "Optimized Core simulation only, same current code with radius 0 versus 26. Not app CPU, rendering, Window Server, battery, or a comparison against the old release.",
            "displayPoints": [3_840, 2_160], "windows": 10, "windowWidthPoints": 650,
            "seed": 17, "intensity": 1, "wind": 0.15, "simulatedFramesPerSecond": 30,
            "warmupFramesPerSample": 900, "measuredFramesPerSample": measuredFrames,
            "trials": 3, "order": "Alternate flat/rounded order each trial, all six effects each trial",
            "samples": samples
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
