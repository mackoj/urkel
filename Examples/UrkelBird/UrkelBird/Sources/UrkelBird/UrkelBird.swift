import Foundation

// MARK: - Domain Model

public struct UrkelBirdContext: Sendable {
    public var altitude: Int
    public var score: Int
    public var tickCount: Int
    public var crashReason: String?

    public init(
        altitude: Int = 0,
        score: Int = 0,
        tickCount: Int = 0,
        crashReason: String? = nil
    ) {
        self.altitude = altitude
        self.score = score
        self.tickCount = tickCount
        self.crashReason = crashReason
    }
}

public enum UrkelBirdEvent: Sendable, Equatable {
    case flap
    case tick(deltaY: Int)
    case scorePipe
    case collide(reason: String)
}

public enum UrkelBirdPhase: String, Sendable {
    case ready
    case playing
    case crashed
}

// MARK: - Runtime Handlers

/// Domain-owned handlers that model a simple Flappy Bird-like loop.
///
/// Generated code provides typestates, transition APIs, dependency wiring, and runtime builder
/// primitives. This sidecar keeps game behavior local and replaceable.
public struct UrkelBirdRuntimeHandlers: Sendable {
    public var onFlap: @Sendable (inout UrkelBirdContext) async throws -> Void
    public var onTick: @Sendable (inout UrkelBirdContext, Int) async throws -> Void
    public var onScorePipe: @Sendable (inout UrkelBirdContext) async throws -> Void
    public var onCollide: @Sendable (inout UrkelBirdContext, String) async throws -> Void

    public init(
        onFlap: @escaping @Sendable (inout UrkelBirdContext) async throws -> Void,
        onTick: @escaping @Sendable (inout UrkelBirdContext, Int) async throws -> Void,
        onScorePipe: @escaping @Sendable (inout UrkelBirdContext) async throws -> Void,
        onCollide: @escaping @Sendable (inout UrkelBirdContext, String) async throws -> Void
    ) {
        self.onFlap = onFlap
        self.onTick = onTick
        self.onScorePipe = onScorePipe
        self.onCollide = onCollide
    }
}

extension UrkelBirdRuntimeHandlers {
    /// A tiny deterministic gameplay model:
    /// - flap raises altitude
    /// - tick applies gravity-like delta and advances frame count
    /// - scorePipe increments score
    /// - collide records crash reason
    public static let simpleGame = Self(
        onFlap: { context in
            context.altitude += 3
        },
        onTick: { context, deltaY in
            context.tickCount += 1
            context.altitude += deltaY
        },
        onScorePipe: { context in
            context.score += 1
        },
        onCollide: { context, reason in
            context.crashReason = reason
        }
    )
}

// MARK: - Client Assembly

extension UrkelBirdClient {
    /// Builds a concrete runtime by adapting domain handlers to generated transition hooks.
    public static func runtime(
        initialContext: @escaping @Sendable () -> UrkelBirdContext = { .init() },
        handlers: UrkelBirdRuntimeHandlers = .simpleGame
    ) -> Self {
        .fromRuntime(
            .init(
                initialContext: initialContext,
                flapTransition: { context in
                    var next = context
                    try await handlers.onFlap(&next)
                    return next
                },
                tickDeltaYIntTransition: { context, deltaY in
                    var next = context
                    try await handlers.onTick(&next, deltaY)
                    return next
                },
                scorePipeTransition: { context in
                    var next = context
                    try await handlers.onScorePipe(&next)
                    return next
                },
                collideReasonStringTransition: { context, reason in
                    var next = context
                    try await handlers.onCollide(&next, reason)
                    return next
                }
            )
        )
    }

    /// A ready-to-use configuration for tests and previews.
    public static var simpleGame: Self {
        .runtime(handlers: .simpleGame)
    }
}

// MARK: - Ergonomic Accessors

extension UrkelBirdObserver {
    /// Returns a snapshot of the game context for assertions and UI rendering.
    public var context: UrkelBirdContext {
        self.withInternalContext { $0 }
    }
}

// MARK: - Convenience Introspection

extension UrkelBirdState {
    /// Returns a context snapshot regardless of current typestate.
    public var context: UrkelBirdContext {
        switch self {
        case let .ready(observer):
            return observer.context
        case let .playing(observer):
            return observer.context
        case let .crashed(observer):
            return observer.context
        }
    }

    /// Whether the state machine currently represents a crashed game.
    public var isCrashed: Bool {
        self.withCrashed { _ in true } ?? false
    }

    /// Lightweight phase value useful for runtime adapters (e.g. GameplayKit).
    public var phase: UrkelBirdPhase {
        switch self {
        case .ready:
            return .ready
        case .playing:
            return .playing
        case .crashed:
            return .crashed
        }
    }
}

// MARK: - Assets

public enum UrkelBirdAssets {
    public static let jumpingSpriteName = "jumping_sprite"

    /// URL to the sprite sheet used by demo renderers.
    public static var jumpingSpriteURL: URL? {
        Bundle.module.url(
            forResource: jumpingSpriteName,
            withExtension: "png",
            subdirectory: "Assets.xcassets/Sprites/jumping_sprite.imageset"
        )
    }
}
