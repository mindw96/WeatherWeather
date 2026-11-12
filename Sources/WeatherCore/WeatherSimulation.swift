import Foundation

public enum WeatherMode: String, CaseIterable, Sendable {
    case snow
    case rain
    case autumn
    case cherryBlossom
    case bubbles
    case confetti
    case fireflies
    case stardust

    public var isSeasonal: Bool { self == .autumn || self == .cherryBlossom }
    public var hasSettledParticles: Bool { isSeasonal || self == .bubbles || self == .confetti || isGlowing }
    public var isGlowing: Bool { self == .fireflies || self == .stardust }
}

/// Coordinates are screen-local points with the origin at the top left.
public struct SurfaceSegment: Equatable, Sendable {
    public var minX: Double
    public var maxX: Double

    public init(minX: Double, maxX: Double) {
        self.minX = minX
        self.maxX = maxX
    }
}

public struct Surface: Equatable, Sendable {
    public var id: UInt32
    public var x: Double
    public var y: Double
    public var width: Double
    /// Visible intervals relative to x. An empty list means a fully covered edge.
    public var segments: [SurfaceSegment]
    public var cornerRadius: Double

    public init(id: UInt32, x: Double, y: Double, width: Double,
                segments: [SurfaceSegment]? = nil, cornerRadius: Double = 0) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.segments = segments ?? [.init(minX: 0, maxX: width)]
        self.cornerRadius = cornerRadius.isFinite && width.isFinite ? min(max(0, cornerRadius), max(0, width / 2)) : 0
    }
}

public struct Particle: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var size: Double
    public var opacity: Double
    public var rotation: Double
    public var angularVelocity: Double
    public var variant: Int
    public var phase: Double
    public var life: Double

    public init(x: Double, y: Double, vx: Double, vy: Double,
                size: Double, opacity: Double, rotation: Double = 0,
                angularVelocity: Double = 0, variant: Int = 0, phase: Double = 0, life: Double = 120) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy
        self.size = size; self.opacity = opacity
        self.rotation = rotation; self.angularVelocity = angularVelocity
        self.variant = variant; self.phase = phase
        self.life = life
    }
}

/// A decorative particle resting in window-local coordinates, independent of its display.
public struct SettledParticle: Equatable, Sendable {
    public var id: UInt64
    public var mode: WeatherMode
    public var surfaceID: UInt32
    public var position: Double
    public var offsetY: Double
    public var size: Double
    public var rotation: Double
    public var variant: Int
    /// Remaining lifetime in seconds; the renderer controls the mode's fade or pop.
    public var life: Double

    public init(id: UInt64, mode: WeatherMode, surfaceID: UInt32, position: Double,
                offsetY: Double, size: Double, rotation: Double, variant: Int, life: Double) {
        self.id = id; self.mode = mode; self.surfaceID = surfaceID
        self.position = position; self.offsetY = offsetY; self.size = size
        self.rotation = rotation; self.variant = variant; self.life = life
    }
}

public struct Pile: Equatable, Sendable {
    public var surfaceID: UInt32
    public var x: Double
    public var y: Double
    public var width: Double
    public var heights: [Double]
    public var segments: [SurfaceSegment]
    public var mode: WeatherMode
    public var cornerRadius: Double = 0

    /// Drawing and swept collisions use the same sampled, rounded upper edge.
    public func baselineY(at localX: Double) -> Double {
        guard cornerRadius > 0, cornerRadius.isFinite, width > 0, width.isFinite,
              heights.count > 1, localX.isFinite else { return y }
        let radius = min(cornerRadius, width / 2)
        let spacing = width / Double(heights.count - 1)
        let position = min(max(localX / width, 0), 1) * Double(heights.count - 1)
        let lower = Int(position), upper = min(lower + 1, heights.count - 1)
        func offset(_ bin: Int) -> Double {
            let x = Double(bin) * spacing
            let distance = max(0, radius - min(x, width - x))
            return radius - sqrt(max(0, radius * radius - distance * distance))
        }
        let fraction = position - Double(lower)
        return y + offset(lower) * (1 - fraction) + offset(upper) * fraction
    }

    public func height(at localX: Double) -> Double {
        guard width > 0, !heights.isEmpty, localX.isFinite else { return 0 }
        let position = min(max(localX / width, 0), 1) * Double(heights.count - 1)
        let lower = Int(position)
        let upper = min(lower + 1, heights.count - 1)
        let fraction = position - Double(lower)
        return heights[lower] * (1 - fraction) + heights[upper] * fraction
    }
}

public struct Splash: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    /// Remaining lifetime, in seconds.
    public var life: Double
    public var size: Double = 1.2
}

/// Every display owns the portion of a window edge inside its horizontal bounds.
/// Off-display copies provide continuity, but never override an owner's deletions.
public struct AccumulationSnapshot: Sendable {
    public var displayWidth: Double
    public var displayHeight: Double
    public var piles: [Pile]
    public var settledParticles: [SettledParticle]

    public init(displayWidth: Double, displayHeight: Double, piles: [Pile], settledParticles: [SettledParticle]) {
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.piles = piles
        self.settledParticles = settledParticles
    }
}

/// A deterministic, renderer-independent simulation. It imports no Apple UI APIs.
/// Each instance belongs to one display; the host provides its visible window edges.
public final class WeatherSimulation {
    public static let maximumParticles = 1_600
    public static let maximumSplashes = 400
    public static let maximumSurfaces = 256
    public static let maximumSnowHeight = 18.0
    public static let maximumWaterHeight = 1.5
    public static let maximumLeafHeight = 10.0
    public static let maximumPetalHeight = 7.0
    public static let maximumBubbleHeight = 10.0
    public static let maximumConfettiHeight = 8.0
    public static let maximumSettledParticles = 1_200

    public var mode: WeatherMode = .snow {
        didSet { if oldValue != mode { reset() } }
    }
    public var intensity: Double = 0.55
    public var wind: Double = 0
    public var movementReactionEnabled = true
    public var accumulationEnabled = true {
        didSet { if !accumulationEnabled { clearAccumulation() } }
    }
    public private(set) var width: Double
    public private(set) var height: Double
    public private(set) var particles: [Particle] = []
    public private(set) var piles: [Pile] = []
    public private(set) var splashes: [Splash] = []
    public private(set) var surfaces: [Surface] = []
    public private(set) var settledParticles: [SettledParticle] = []

    private var random: SeededRandom
    private var emissionRemainder = 0.0
    private var elapsed = 0.0
    private var lastSnowMotion: [UInt32: Double] = [:]

    public var accumulationSnapshot: AccumulationSnapshot {
        AccumulationSnapshot(displayWidth: width, displayHeight: height, piles: piles.filter { $0.surfaceID != 0 },
                             settledParticles: settledParticles.filter { $0.surfaceID != 0 })
    }

    public init(width: Double, height: Double, seed: UInt64 = 0x5745_4154_4845_52) {
        self.width = Self.validDimension(width)
        self.height = Self.validDimension(height)
        random = SeededRandom(state: seed)
    }

    public func resize(width: Double, height: Double) {
        self.width = Self.validDimension(width)
        self.height = Self.validDimension(height)
        particles.removeAll { $0.x < -60 || $0.x > self.width + 60 || $0.y > self.height + 60 }
    }

    /// Stable IDs preserve snow/water when a window moves. Removed IDs lose their pile.
    public func setSurfaces(_ newSurfaces: [Surface], inheriting snapshots: [AccumulationSnapshot] = []) {
        guard newSurfaces != surfaces || !snapshots.isEmpty else { return }
        var ids = Set<UInt32>()
        surfaces = newSurfaces.compactMap { surface in
            guard ids.count < Self.maximumSurfaces,
                  surface.x.isFinite, surface.y.isFinite,
                  surface.width.isFinite, surface.width >= 1,
                  surface.width <= 65_536, ids.insert(surface.id).inserted else { return nil }
            var result = surface
            result.cornerRadius = surface.id != 0 && surface.cornerRadius.isFinite
                ? min(max(0, surface.cornerRadius), surface.width / 2) : 0
            result.segments = surface.segments.compactMap { segment in
                guard segment.minX.isFinite, segment.maxX.isFinite else { return nil }
                let start = max(0, segment.minX), end = min(surface.width, segment.maxX)
                return start < end ? .init(minX: start, maxX: end) : nil
            }
            return result
        }
        let previous = Dictionary(uniqueKeysWithValues: piles.map { ($0.surfaceID, $0) })
        piles = surfaces.map { surface in
            let count = min(2_048, max(2, Int(ceil(surface.width / (surface.cornerRadius > 0 ? 2 : 6))) + 1))
            let old = previous[surface.id]
            let heights: [Double]
            if let old, old.width == surface.width, old.heights.count == count {
                heights = old.heights
            } else {
                heights = (0..<count).map { index -> Double in
                    guard let old else { return 0 }
                    return old.height(at: Double(index) / Double(count - 1) * old.width)
                }
            }
            return Pile(surfaceID: surface.id, x: surface.x, y: surface.y,
                        width: surface.width, heights: heights,
                        segments: surface.segments, mode: mode, cornerRadius: surface.cornerRadius)
        }
        settledParticles.removeAll { !ids.contains($0.surfaceID) }
        lastSnowMotion = lastSnowMotion.filter { ids.contains($0.key) }
        if accumulationEnabled, !snapshots.isEmpty { synchronizeAccumulation(from: snapshots) }
        if mode == .snow, accumulationEnabled, movementReactionEnabled {
            shedMovingSnow(previous: previous)
        }
    }

    private func synchronizeAccumulation(from snapshots: [AccumulationSnapshot]) {
        struct Source {
            var pile: Pile
            var displayWidth: Double
            var displayHeight: Double
            var particles: [UInt64: SettledParticle]
            func owns(_ position: Double) -> Bool {
                let x = pile.x + position * pile.width
                let y = pile.baselineY(at: position * pile.width)
                return x >= 0 && x < displayWidth && y >= 0 && y < displayHeight
            }
        }
        var sources: [UInt32: [Source]] = [:]
        for snapshot in snapshots where snapshot.displayWidth.isFinite && snapshot.displayWidth > 0
            && snapshot.displayHeight.isFinite && snapshot.displayHeight > 0 {
            let particles = Dictionary(grouping: snapshot.settledParticles, by: \.surfaceID)
            for pile in snapshot.piles where pile.surfaceID != 0 && pile.mode == mode
                && pile.width.isFinite && pile.width > 0 && pile.x.isFinite && pile.y.isFinite && !pile.heights.isEmpty {
                let items = Dictionary((particles[pile.surfaceID] ?? []).map { ($0.id, $0) },
                                       uniquingKeysWith: { first, _ in first })
                sources[pile.surfaceID, default: []].append(Source(pile: pile, displayWidth: snapshot.displayWidth,
                                                                  displayHeight: snapshot.displayHeight, particles: items))
            }
        }
        var transferred: [SettledParticle] = []
        let cap = maximumAccumulationHeight
        for index in piles.indices where piles[index].surfaceID != 0 {
            guard let candidates = sources[piles[index].surfaceID], let fallback = candidates.first else { continue }
            for bin in piles[index].heights.indices {
                let position = Double(bin) / Double(piles[index].heights.count - 1)
                let source = candidates.first(where: { $0.owns(position) }) ?? fallback
                let value = source.pile.height(at: position * source.pile.width)
                piles[index].heights[bin] = value.isFinite ? min(cap, max(0, value)) : 0
            }
            var visited = Set<UInt64>()
            for candidate in candidates {
                for id in candidate.particles.keys.sorted() where visited.insert(id).inserted {
                    guard let particle = candidate.particles[id], particle.position.isFinite else { continue }
                    // A missing item on its owning display means it expired or lifted off.
                    let owner = candidates.first(where: { $0.owns(particle.position) }) ?? candidate
                    if let value = owner.particles[id] { transferred.append(value) }
                }
            }
        }
        let synchronizedIDs = Set(piles.map(\.surfaceID)).intersection(sources.keys)
        settledParticles.removeAll { synchronizedIDs.contains($0.surfaceID) }
        inheritSettledParticles(from: transferred)
    }

    /// Merges window-local accumulation captured from other displays in this refresh.
    /// Call after setSurfaces, using a fresh snapshot taken after any global clear or
    /// mode change. Screen floors stay independent, and no missing surface is created.
    public func inheritAccumulation(from sourcePiles: [Pile]) {
        guard accumulationEnabled else { return }
        let maximum = maximumAccumulationHeight
        let sources = Dictionary(grouping: sourcePiles.filter {
            $0.surfaceID != 0 && $0.mode == mode && $0.width.isFinite
                && $0.width > 0 && !$0.heights.isEmpty
        }, by: \.surfaceID)
        func bounded(_ value: Double) -> Double {
            value.isFinite ? min(max(value, 0), maximum) : 0
        }
        for index in piles.indices where piles[index].surfaceID != 0 {
            guard let matching = sources[piles[index].surfaceID] else { continue }
            var heights = piles[index].heights.map(bounded)
            for source in matching {
                for bin in heights.indices {
                    let position = Double(bin) / Double(max(1, heights.count - 1))
                        * Double(source.heights.count - 1)
                    let lower = Int(position)
                    let upper = min(lower + 1, source.heights.count - 1)
                    let fraction = position - Double(lower)
                    let inherited = bounded(source.heights[lower]) * (1 - fraction)
                        + bounded(source.heights[upper]) * fraction
                    heights[bin] = max(heights[bin], inherited)
                }
            }
            piles[index].heights = heights
        }
    }

    /// Call alongside inheritAccumulation with a fresh snapshot after any global clear.
    /// Stable particle IDs make repeated cross-display synchronization idempotent.
    public func inheritSettledParticles(from sourceParticles: [SettledParticle]) {
        guard accumulationEnabled, mode.hasSettledParticles else { return }
        let surfaceIDs = Set(surfaces.map(\.id))
        var positions = Dictionary(uniqueKeysWithValues: settledParticles.enumerated().map { ($0.element.id, $0.offset) })
        for particle in sourceParticles {
            guard particle.surfaceID != 0, particle.mode == mode,
                  surfaceIDs.contains(particle.surfaceID),
                  particle.position.isFinite, (0...1).contains(particle.position),
                  particle.offsetY.isFinite, particle.offsetY >= 0,
                  particle.offsetY <= maximumAccumulationHeight + 20,
                  particle.size.isFinite, particle.size > 0,
                  particle.size <= (mode == .confetti ? 9 : mode == .fireflies ? 3.6 : mode == .stardust ? 6 : 20),
                  mode != .bubbles || particle.size >= 10,
                  particle.rotation.isFinite, (0..<(mode == .confetti ? 6 : 3)).contains(particle.variant),
                  particle.life.isFinite, particle.life > 0,
                  particle.life <= settledLifetime else { continue }
            if let existing = positions[particle.id] {
                // A copied particle never becomes younger as it crosses a screen seam.
                settledParticles[existing].life = min(settledParticles[existing].life, particle.life)
            } else {
                positions[particle.id] = settledParticles.count
                settledParticles.append(particle)
            }
        }
        trimSettledParticles()
    }

    public func clearAccumulation() {
        settledParticles.removeAll(keepingCapacity: true)
        for index in piles.indices {
            piles[index].heights = Array(repeating: 0, count: piles[index].heights.count)
        }
    }

    public func reset() {
        particles.removeAll(keepingCapacity: true)
        splashes.removeAll(keepingCapacity: true)
        emissionRemainder = 0
        elapsed = 0
        lastSnowMotion.removeAll(keepingCapacity: true)
        clearAccumulation()
        for index in piles.indices { piles[index].mode = mode }
    }

    /// A delayed frame advances at most 100 ms, avoiding post-sleep bursts.
    public func update(deltaTime: Double) {
        guard deltaTime.isFinite, deltaTime > 0 else { return }
        let dt = min(deltaTime, 0.1)
        elapsed += dt
        let density = intensity.isFinite ? min(max(intensity, 0), 1) : 0
        let breeze = wind.isFinite ? min(max(wind, -1), 1) : 0
        let baseRate: Double
        switch mode {
        case .snow: baseRate = 72
        case .rain: baseRate = 230
        case .autumn: baseRate = 18
        case .cherryBlossom: baseRate = 25
        case .bubbles: baseRate = 12
        case .confetti: baseRate = 35
        case .fireflies: baseRate = 8
        case .stardust: baseRate = 18
        }
        let rate = baseRate * min(width / 1_000, 4) * density
        emissionRemainder += rate * dt
        let requested = Int(emissionRemainder)
        emissionRemainder -= Double(requested)
        let count = min(requested, Self.maximumParticles - particles.count)
        if count > 0 {
            for _ in 0..<count { spawnParticle(wind: breeze) }
        }

        let decay = mode == .snow ? 0.006 : (mode == .rain ? 0.07 : (mode == .bubbles ? 0.8 : 0.08))
        for index in piles.indices {
            for bin in piles[index].heights.indices {
                piles[index].heights[bin] = max(0, piles[index].heights[bin] - decay * dt)
            }
        }

        if movementReactionEnabled, accumulationEnabled, mode.isSeasonal, abs(breeze) > 0.65 {
            liftSettledParticles(wind: breeze, deltaTime: dt)
        }

        var survivors: [Particle] = []
        survivors.reserveCapacity(particles.count)
        for var particle in particles {
            particle.life -= dt
            guard particle.life > 0 else { continue }
            let oldX = particle.x, oldY = particle.y
            switch mode {
            case .snow:
                particle.vx = breeze * 65 + sin(elapsed * 1.4 + particle.size * 7 + particle.y * 0.009) * 16
            case .rain:
                particle.vx = breeze * 150
            case .autumn:
                particle.vx = breeze * 100 + sin(elapsed * 1.8 + particle.phase + particle.y * 0.004) * 35
                particle.rotation += (particle.angularVelocity + sin(elapsed * 2 + particle.phase) * 0.3) * dt
            case .cherryBlossom:
                particle.vx = breeze * 80 + sin(elapsed * 1.1 + particle.phase + particle.y * 0.003) * 25
                particle.rotation += (particle.angularVelocity + sin(elapsed + particle.phase) * 0.2) * dt
            case .bubbles:
                particle.vx = breeze * 55 + sin(elapsed * 0.9 + particle.phase + particle.y * 0.005) * 20
                particle.rotation += particle.angularVelocity * dt
            case .confetti:
                particle.vx = breeze * 95 + sin(elapsed * 2.4 + particle.phase + particle.y * 0.006) * 30
                particle.rotation += (particle.angularVelocity + sin(elapsed * 3 + particle.phase) * 0.6) * dt
            case .fireflies:
                particle.vx = breeze * 35 + sin(elapsed * 1.2 + particle.phase) * 23
                particle.vy = 16 + sin(elapsed * 1.6 + particle.phase) * 13
                particle.opacity = 0.35 + 0.6 * pow((sin(elapsed * 2.2 + particle.phase) + 1) / 2, 2)
            case .stardust:
                particle.vx = breeze * 55 + sin(elapsed + particle.phase) * 12
                particle.rotation += particle.angularVelocity * dt
                particle.opacity = 0.55 + 0.4 * (sin(elapsed * 3.2 + particle.phase) + 1) / 2
            }
            if mode.isSeasonal, particle.vy < 25 { particle.vy = min(25, particle.vy + 100 * dt) }
            particle.x += particle.vx * dt
            let flutter = mode.isSeasonal || mode == .confetti ? 0.85 + 0.15 * sin(elapsed * 2 + particle.phase) : 1
            particle.y += particle.vy * flutter * dt
            if let hit = firstCollision(fromX: oldX, y: oldY, toX: particle.x, y: particle.y) {
                if accumulationEnabled {
                    accumulate(at: hit)
                    if mode.hasSettledParticles { settle(particle, at: hit) }
                }
            } else if particle.y > -160, particle.y < height + 50, particle.x > -80, particle.x < width + 80 {
                survivors.append(particle)
            }
        }
        particles = survivors

        for index in splashes.indices {
            splashes[index].x += splashes[index].vx * dt
            splashes[index].y += splashes[index].vy * dt
            splashes[index].vy += 430 * dt
            splashes[index].life -= dt
        }
        splashes.removeAll { $0.life <= 0 || $0.y > height + 30 }

        if mode.hasSettledParticles {
            for index in settledParticles.indices { settledParticles[index].life -= dt }
            settledParticles.removeAll { $0.life <= 0 }
            // No invisible collision ridge survives after the last resting particle expires.
            let occupied = Set(settledParticles.map(\.surfaceID))
            for index in piles.indices where !occupied.contains(piles[index].surfaceID) {
                piles[index].heights = Array(repeating: 0, count: piles[index].heights.count)
            }
        }
    }

    private func spawnParticle(wind: Double) {
        if mode.isGlowing {
            let firefly = mode == .fireflies
            particles.append(Particle(
                x: random.between(-15, width + 15), y: random.between(-20, -3),
                vx: wind * (firefly ? 35 : 55), vy: random.between(firefly ? 8 : 24, firefly ? 22 : 48),
                size: random.between(firefly ? 2 : 3, firefly ? 3.6 : 6), opacity: 0.8,
                rotation: random.between(-Double.pi, Double.pi), angularVelocity: random.between(-0.7, 0.7),
                variant: Int(random.between(0, 3)), phase: random.between(0, Double.pi * 2), life: 60))
            return
        }
        if mode == .bubbles || mode == .confetti {
            let bubble = mode == .bubbles
            particles.append(Particle(
                x: random.between(-30, width + 30), y: random.between(-35, -4),
                vx: wind * (bubble ? 55 : 95),
                vy: random.between(bubble ? 18 : 45, bubble ? 38 : 100),
                size: random.between(bubble ? 10 : 5, bubble ? 20 : 9),
                opacity: random.between(bubble ? 0.45 : 0.85, bubble ? 0.8 : 1),
                rotation: random.between(-Double.pi, Double.pi),
                angularVelocity: random.between(bubble ? -0.3 : -4, bubble ? 0.3 : 4),
                variant: Int(random.between(0, bubble ? 3 : 6)), phase: random.between(0, Double.pi * 2)))
            return
        }
        if mode.isSeasonal {
            let leaf = mode == .autumn
            particles.append(Particle(
                x: random.between(-30, width + 30), y: random.between(-35, -4),
                vx: wind * (leaf ? 100 : 80),
                vy: random.between(leaf ? 40 : 25, leaf ? 95 : 65),
                size: random.between(leaf ? 7 : 5, leaf ? 14 : 9),
                opacity: random.between(leaf ? 0.8 : 0.72, leaf ? 1 : 0.95),
                rotation: random.between(-Double.pi, Double.pi),
                angularVelocity: random.between(leaf ? -2 : -1.4, leaf ? 2 : 1.4),
                variant: Int(random.between(0, 3)), phase: random.between(0, Double.pi * 2)))
            return
        }
        let snow = mode == .snow
        particles.append(Particle(
            x: random.between(-30, width + 30), y: random.between(-35, -4),
            vx: wind * (snow ? 65 : 150),
            vy: random.between(snow ? 30 : 650, snow ? 86 : 1_100),
            size: random.between(snow ? 1.3 : 0.7, snow ? 3.5 : 1.4),
            opacity: random.between(snow ? 0.45 : 0.16, snow ? 0.95 : 0.42)))
    }

    struct Collision {
        var pileIndex: Int
        var x: Double
        var y: Double
        var fraction: Double
    }

    /// Swept intersection prevents fast rain from tunnelling through window edges.
    func firstCollision(fromX x0: Double, y y0: Double, toX x1: Double, y y1: Double) -> Collision? {
        guard x0.isFinite, y0.isFinite, x1.isFinite, y1.isFinite, y1 > y0 else { return nil }
        var nearest: Collision?
        let maximumHeight = maximumAccumulationHeight
        let dx = x1 - x0, dy = y1 - y0
        for index in piles.indices {
            let pile = piles[index]
            // Skip edges outside the swept particle bounds before sampling the ridge.
            guard !pile.segments.isEmpty,
                  y0 <= pile.y + pile.cornerRadius, y1 >= pile.y - maximumHeight,
                  max(x0, x1) >= pile.x, min(x0, x1) <= pile.x + pile.width else { continue }
            if dx == 0 {
                let localX = x0 - pile.x
                let top = pile.baselineY(at: localX) - pile.height(at: localX)
                let t = (top - y0) / dy
                if t >= 0, t <= 1,
                   pile.segments.contains(where: { localX >= $0.minX && localX <= $0.maxX }),
                   nearest == nil || t < nearest!.fraction {
                    nearest = Collision(pileIndex: index, x: x0, y: top, fraction: t)
                }
                continue
            }
            let spacing = pile.width / Double(pile.heights.count - 1)
            let first = min(pile.heights.count - 2, max(0, Int(floor((min(x0, x1) - pile.x) / spacing))))
            let last = min(pile.heights.count - 2, max(0, Int(floor((max(x0, x1) - pile.x) / spacing))))
            // Visit only the profile bins crossed by this step; each is an exact line intersection.
            for bin in first...last {
                let left = Double(bin) * spacing, right = Double(bin + 1) * spacing
                let t0 = (pile.x + left - x0) / dx, t1 = (pile.x + right - x0) / dx
                let start = max(0, min(t0, t1)), end = min(1, max(t0, t1))
                guard start <= end, nearest == nil || start <= nearest!.fraction else { continue }
                let topLeft = pile.baselineY(at: left) - pile.heights[bin]
                let topRight = pile.baselineY(at: right) - pile.heights[bin + 1]
                let slope = (topRight - topLeft) / spacing
                let crossingSpeed = dy - slope * dx
                guard crossingSpeed > 0 else { continue }
                let t = (topLeft + slope * (x0 - pile.x - left) - y0) / crossingSpeed
                guard t >= start, t <= end, nearest == nil || t < nearest!.fraction else { continue }
                let x = x0 + dx * t, localX = x - pile.x
                guard pile.segments.contains(where: { localX >= $0.minX && localX <= $0.maxX }) else { continue }
                nearest = Collision(pileIndex: index, x: x, y: y0 + dy * t, fraction: t)
            }
        }
        return nearest
    }

    private func accumulate(at hit: Collision) {
        let snow = mode == .snow
        let radius = snow ? random.between(9, 18) : (mode == .rain ? 30 : 12)
        let amount = snow ? random.between(0.38, 0.9) : (mode == .rain ? 0.17 : 0.35)
        let pile = piles[hit.pileIndex]
        let impact = hit.x - pile.x
        let spacing = pile.width / Double(pile.heights.count - 1)
        let low = max(0, Int(floor((impact - radius) / spacing)))
        let high = min(pile.heights.count - 1, Int(ceil((impact + radius) / spacing)))
        guard low <= high else { return }
        for bin in low...high {
            let localX = Double(bin) * spacing
            guard pile.segments.contains(where: { localX >= $0.minX && localX <= $0.maxX }) else { continue }
            let distance = abs(localX - impact) / radius
            guard distance < 1 else { continue }
            // The smooth kernel gives a soft ridge without textures or copied assets.
            let addition = amount * pow(1 - distance * distance, 2)
            let maximum = snow ? snowCapacity(at: localX, in: pile) : maximumAccumulationHeight
            piles[hit.pileIndex].heights[bin] = min(maximum, pile.heights[bin] + addition)
        }
    }

    private var maximumAccumulationHeight: Double {
        switch mode {
        case .snow: return Self.maximumSnowHeight
        case .rain: return Self.maximumWaterHeight
        case .autumn: return Self.maximumLeafHeight
        case .cherryBlossom: return Self.maximumPetalHeight
        case .bubbles: return Self.maximumBubbleHeight
        case .confetti: return Self.maximumConfettiHeight
        case .fireflies, .stardust: return 4
        }
    }

    private var settledLifetime: Double {
        switch mode {
        case .autumn: return 90
        case .bubbles: return 10
        case .confetti: return 45
        case .fireflies: return 4
        case .stardust: return 8
        default: return 60
        }
    }

    private func settle(_ particle: Particle, at hit: Collision) {
        let pile = piles[hit.pileIndex]
        let localX = min(max(hit.x - pile.x, 0), pile.width)
        settledParticles.append(SettledParticle(
            id: random.next(), mode: mode, surfaceID: pile.surfaceID,
            position: localX / pile.width,
            offsetY: pile.height(at: localX) + particle.size * (mode == .bubbles ? 0.5 : random.between(0.15, 0.45)),
            size: particle.size, rotation: random.between(-Double.pi, Double.pi),
            variant: particle.variant, life: min(settledLifetime, particle.life)))
        trimSettledParticles()
    }

    private func trimSettledParticles() {
        let excess = settledParticles.count - Self.maximumSettledParticles
        if excess > 0 { settledParticles.removeFirst(excess) }
    }

    private func shedMovingSnow(previous: [UInt32: Pile]) {
        for index in piles.indices {
            let pile = piles[index]
            guard pile.surfaceID != 0, let old = previous[pile.surfaceID],
                  abs(old.width - pile.width) < 0.5, !pile.segments.isEmpty else { continue }
            let dx = pile.x - old.x, dy = pile.y - old.y
            let distance = hypot(dx, dy)
            // Large jumps usually represent a display/Space transition, not a drag.
            guard distance >= 4, distance <= 220,
                  elapsed - (lastSnowMotion[pile.surfaceID] ?? -1) >= 0.16 else { continue }
            lastSnowMotion[pile.surfaceID] = elapsed
            for side in [0, 1] {
                for _ in 0..<3 where splashes.count < Self.maximumSplashes {
                    let inset = random.between(6, min(45, max(7, pile.width / 3)))
                    let x = side == 0 ? inset : pile.width - inset
                    guard x >= 0, x <= pile.width,
                          pile.x + x >= 0, pile.x + x < width,
                          pile.baselineY(at: x) >= 0, pile.baselineY(at: x) < height,
                          pile.segments.contains(where: { x >= $0.minX && x <= $0.maxX }),
                          pile.height(at: x) > 1 else { continue }
                    splashes.append(Splash(x: pile.x + x, y: pile.baselineY(at: x) - pile.height(at: x),
                                           vx: min(120, max(-120, -dx * 2)) + (side == 0 ? -35 : 35),
                                           vy: -random.between(25, 70), life: random.between(0.5, 0.9),
                                           size: random.between(2, min(5, 2 + pile.height(at: x) / 3))))
                    lowerPile(at: x, index: index, amount: min(2, distance / 30))
                }
            }
        }
    }

    private func lowerPile(at localX: Double, index: Int, amount: Double) {
        let count = piles[index].heights.count
        let center = Int((localX / piles[index].width * Double(count - 1)).rounded())
        for bin in max(0, center - 2)...min(count - 1, center + 2) {
            let x = piles[index].x + Double(bin) / Double(count - 1) * piles[index].width
            let y = piles[index].baselineY(at: x - piles[index].x)
            guard x >= 0, x < width, y >= 0, y < height else { continue }
            piles[index].heights[bin] = max(0, piles[index].heights[bin] - amount)
        }
    }

    private func liftSettledParticles(wind: Double, deltaTime: Double) {
        let indices = Dictionary(uniqueKeysWithValues: piles.enumerated().map { ($0.element.surfaceID, $0.offset) })
        var lifted = Set<UInt64>()
        for item in settledParticles {
            guard lifted.count < 4, particles.count < Self.maximumParticles else { break }
            guard item.life > 1, let index = indices[item.surfaceID],
                  random.between(0, 1) < (abs(wind) - 0.65) * deltaTime * 1.5 else { continue }
            let pile = piles[index], x = item.position * piles[index].width
            guard pile.x + x >= 0, pile.x + x < width,
                  pile.baselineY(at: x) >= 0, pile.baselineY(at: x) < height,
                  pile.segments.contains(where: { x >= $0.minX && x <= $0.maxX }) else { continue }
            particles.append(Particle(x: pile.x + x, y: pile.baselineY(at: x) - item.offsetY - item.size,
                                      vx: wind * 100, vy: -random.between(45, 90), size: item.size,
                                      opacity: 0.9, rotation: item.rotation,
                                      angularVelocity: random.between(-3, 3), variant: item.variant,
                                      phase: random.between(0, Double.pi * 2), life: item.life))
            lowerPile(at: x, index: index, amount: 0.35)
            lifted.insert(item.id)
        }
        settledParticles.removeAll { lifted.contains($0.id) }
    }

    /// A stable, gently uneven saturation profile prevents long-running snow from
    /// becoming a flat bar. Actual stored heights still drive both drawing and collision.
    private func snowCapacity(at localX: Double, in pile: Pile) -> Double {
        let phase = Double(pile.surfaceID % 997) * 0.017
        let ridge = 13.5 + 2.0 * sin(localX / 52 + phase)
            + 1.2 * sin(localX / 19 + phase * 1.3)
        let edge = min(max(0, min(localX, pile.width - localX)) / 10, 1)
        let taper = edge * edge * (3 - 2 * edge)
        return min(Self.maximumSnowHeight, ridge * taper)
    }

    private static func validDimension(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 1), 32_768) : 1
    }
}

private struct SeededRandom {
    var state: UInt64

    mutating func between(_ lower: Double, _ upper: Double) -> Double {
        let unit = Double(next() >> 11) / 9_007_199_254_740_992
        return lower + (upper - lower) * unit
    }

    mutating func next() -> UInt64 {
        // SplitMix64 supports every seed, including zero, and has no OS dependency.
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return value
    }
}
