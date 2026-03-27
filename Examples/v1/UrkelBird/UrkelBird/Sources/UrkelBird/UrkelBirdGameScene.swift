import Foundation
import GameplayKit
import SpriteKit

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Scene Visuals

private enum UrkelBirdSceneVisual {
    static let sceneBackground = SKColor(red: 0.04, green: 0.08, blue: 0.16, alpha: 1)
    static let corridorFill = SKColor(red: 0.10, green: 0.16, blue: 0.24, alpha: 1)
    static let wallColor = SKColor(red: 0.95, green: 0.70, blue: 0.20, alpha: 1)
    static let floorColor = SKColor(red: 0.65, green: 0.40, blue: 0.15, alpha: 1)
    static let collisionBorderColor = SKColor.green
    static let collisionBorderWidth: CGFloat = 2

    static let worldScale: CGFloat = 8
    static let playerXRatio: CGFloat = 0.33
    static let wallSpeedPerTick: CGFloat = 9
    static let wallWidth: CGFloat = 52
    static let gapHeight: CGFloat = 160
    static let birdDisplayHeight: CGFloat = 56
    static let fallbackBirdSize = CGSize(width: 44, height: 44)
    static let birdHitboxInsetRatio: CGFloat = 0.16
}

private struct UrkelBirdSceneSnapshot: Sendable {
    struct DebugEvent: Sendable {
        var trigger: String
        var from: UrkelBirdPhase
        var to: UrkelBirdPhase
    }

    var context: UrkelBirdContext
    var crashed: Bool
    var phase: UrkelBirdPhase
    var debugEvent: DebugEvent?
}

// MARK: - Runtime Driver

private actor UrkelBirdSceneRuntime {
    enum Command: Sendable {
        case flap
        case reset
        case tick
        case collide(reason: String)
        case stop
    }

    private let commands: AsyncStream<Command>
    private var continuation: AsyncStream<Command>.Continuation?
    private var loopTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var latest = UrkelBirdSceneSnapshot(context: .init(), crashed: false, phase: .ready, debugEvent: nil)

    init() {
        var captured: AsyncStream<Command>.Continuation?
        self.commands = AsyncStream { continuation in
            captured = continuation
        }
        self.continuation = captured
    }

    func start() {
        guard loopTask == nil else { return }

        let stream = commands
        let runtime = self

        loopTask = Task.detached {
            var state = Self.makeInitialState()
            var tickAccumulator = 0
            await runtime.publish(
                from: .ready,
                trigger: "start",
                context: state.context,
                crashed: state.isCrashed,
                phase: state.phase
            )

            for await command in stream {
                let fromPhase = state.phase
                var trigger = ""

                switch command {
                case .flap:
                    trigger = "flap"
                    state = try! await state.flap()

                case .reset:
                    trigger = "reset"
                    state = Self.makeInitialState()
                    tickAccumulator = 0

                case .tick:
                    trigger = "tick"
                    guard !state.isCrashed else {
                        await runtime.publish(
                            from: fromPhase,
                            trigger: trigger,
                            context: state.context,
                            crashed: state.isCrashed,
                            phase: state.phase
                        )
                        continue
                    }

                    state = try! await state.tick(deltaY: -1)
                    tickAccumulator += 1

                    if tickAccumulator >= 8 {
                        tickAccumulator = 0
                        trigger = "scorePipe"
                        state = try! await state.scorePipe()
                    }

                case let .collide(reason):
                    trigger = "collide"
                    guard !state.isCrashed else {
                        await runtime.publish(
                            from: fromPhase,
                            trigger: trigger,
                            context: state.context,
                            crashed: state.isCrashed,
                            phase: state.phase
                        )
                        continue
                    }
                    state = try! await state.collide(reason: reason)

                case .stop:
                    return
                }

                await runtime.publish(
                    from: fromPhase,
                    trigger: trigger,
                    context: state.context,
                    crashed: state.isCrashed,
                    phase: state.phase
                )
            }
        }

        tickTask = Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                await runtime.enqueue(.tick)
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        enqueue(.stop)
        loopTask?.cancel()
        loopTask = nil
    }

    func flap() {
        enqueue(.flap)
    }

    func reset() {
        enqueue(.reset)
    }

    func collide(reason: String) {
        enqueue(.collide(reason: reason))
    }

    func snapshot() -> UrkelBirdSceneSnapshot {
        latest
    }

    private func publish(
        from: UrkelBirdPhase,
        trigger: String,
        context: UrkelBirdContext,
        crashed: Bool,
        phase: UrkelBirdPhase
    ) {
        let to = phase
        let event: UrkelBirdSceneSnapshot.DebugEvent? = trigger.isEmpty
            ? nil
            : .init(trigger: trigger, from: from, to: to)

        latest = .init(
            context: context,
            crashed: crashed,
            phase: to,
            debugEvent: event
        )
    }

    private func enqueue(_ command: Command) {
        continuation?.yield(command)
    }

    private static func makeInitialState() -> UrkelBirdState {
        let gameLogic = UrkelBirdClient.simpleGame.makeGame()
        return UrkelBirdState(gameLogic)
    }
}

// MARK: - Public SpriteKit Scene

/// SpriteKit scene powered by the generated UrkelBird state machine.
///
/// - macOS controls:
///   - `Space`: flap
///   - `R`: reset
/// - iOS/tvOS/visionOS controls:
///   - tap: flap (or reset when crashed)
public final class UrkelBirdGameScene: SKScene {
    // GameplayKit state machine mirrors generated Urkel phase.
    private final class ReadyPhaseState: GKState {}
    private final class PlayingPhaseState: GKState {}
    private final class CrashedPhaseState: GKState {}

    private let runtime = UrkelBirdSceneRuntime()
    private let phaseMachine = GKStateMachine(states: [
        ReadyPhaseState(),
        PlayingPhaseState(),
        CrashedPhaseState()
    ])

    private let backgroundNode = SKShapeNode()
    private let floorNode = SKShapeNode()
    private let corridorNode = SKShapeNode()
    private let birdNode = SKSpriteNode()
    private let birdHitboxNode = SKShapeNode()
    private let leftWallNode = SKShapeNode()
    private let rightWallNode = SKShapeNode()

    private let hudNode = SKLabelNode(fontNamed: "Menlo")
    private let eventNode = SKLabelNode(fontNamed: "Menlo")
    private let helpNode = SKLabelNode(fontNamed: "Menlo")

    private var renderTask: Task<Void, Never>?
    private var wallOffset: CGFloat = 0
    private var wallGapCenter: CGFloat = 0
    private var hasBirdTexture = false
    private var floorRect: CGRect = .zero
    private var lowerWallRect: CGRect = .zero
    private var upperWallRect: CGRect = .zero
    private var collisionRequestInFlight = false

    public override init(size: CGSize) {
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.backgroundColor = UrkelBirdSceneVisual.sceneBackground
        phaseMachine.enter(ReadyPhaseState.self)
    }

    public required init?(coder aDecoder: NSCoder) {
        nil
    }

    deinit {
        renderTask?.cancel()
    }

    public override func didMove(to view: SKView) {
        #if os(macOS)
        view.window?.makeFirstResponder(view)
        #endif
        setupNodes()
        Task { [runtime] in
            await runtime.start()
        }
        startRenderLoop()
    }

    public override func willMove(from view: SKView) {
        renderTask?.cancel()
        renderTask = nil
        Task { [runtime] in
            await runtime.stop()
        }
    }

    #if os(macOS)
    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49: // space
            Task { [runtime] in
                await runtime.flap()
            }
        case 15: // r
            Task { [runtime] in
                await runtime.reset()
            }
        default:
            break
        }
    }
    #endif

    #if os(iOS) || os(tvOS) || os(visionOS)
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        Task { [runtime] in
            let snapshot = await runtime.snapshot()
            if snapshot.crashed {
                await runtime.reset()
            } else {
                await runtime.flap()
            }
        }
    }
    #endif

    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutWorldGeometry()
    }

    private func setupNodes() {
        backgroundNode.fillColor = UrkelBirdSceneVisual.sceneBackground
        backgroundNode.strokeColor = UrkelBirdSceneVisual.collisionBorderColor
        backgroundNode.lineWidth = 1
        backgroundNode.zPosition = 0
        addChild(backgroundNode)

        corridorNode.fillColor = UrkelBirdSceneVisual.corridorFill
        corridorNode.strokeColor = UrkelBirdSceneVisual.collisionBorderColor
        corridorNode.lineWidth = UrkelBirdSceneVisual.collisionBorderWidth
        corridorNode.zPosition = 1
        addChild(corridorNode)

        floorNode.fillColor = UrkelBirdSceneVisual.floorColor
        floorNode.strokeColor = UrkelBirdSceneVisual.collisionBorderColor
        floorNode.lineWidth = UrkelBirdSceneVisual.collisionBorderWidth
        floorNode.zPosition = 2
        addChild(floorNode)

        leftWallNode.fillColor = UrkelBirdSceneVisual.wallColor
        leftWallNode.strokeColor = UrkelBirdSceneVisual.collisionBorderColor
        leftWallNode.lineWidth = UrkelBirdSceneVisual.collisionBorderWidth
        leftWallNode.zPosition = 5
        addChild(leftWallNode)

        rightWallNode.fillColor = UrkelBirdSceneVisual.wallColor
        rightWallNode.strokeColor = UrkelBirdSceneVisual.collisionBorderColor
        rightWallNode.lineWidth = UrkelBirdSceneVisual.collisionBorderWidth
        rightWallNode.zPosition = 5
        addChild(rightWallNode)

        configureBirdNode()
        birdNode.zPosition = 10
        addChild(birdNode)

        birdHitboxNode.fillColor = .clear
        birdHitboxNode.strokeColor = UrkelBirdSceneVisual.collisionBorderColor
        birdHitboxNode.lineWidth = UrkelBirdSceneVisual.collisionBorderWidth
        birdHitboxNode.zPosition = 11
        addChild(birdHitboxNode)

        hudNode.fontSize = 14
        hudNode.horizontalAlignmentMode = .left
        hudNode.verticalAlignmentMode = .top
        hudNode.zPosition = 20
        addChild(hudNode)

        eventNode.fontSize = 12
        eventNode.horizontalAlignmentMode = .left
        eventNode.verticalAlignmentMode = .top
        eventNode.fontColor = .cyan
        eventNode.zPosition = 20
        addChild(eventNode)

        helpNode.fontSize = 12
        helpNode.horizontalAlignmentMode = .left
        helpNode.verticalAlignmentMode = .bottom
        helpNode.text = "Space/tap: flap  |  R or tap after crash: restart"
        helpNode.fontColor = .white
        helpNode.zPosition = 20
        addChild(helpNode)

        layoutWorldGeometry()
    }

    private func layoutWorldGeometry() {
        backgroundNode.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)

        corridorNode.path = CGPath(
            roundedRect: CGRect(
                x: 8,
                y: 8,
                width: max(0, size.width - 16),
                height: max(0, size.height - 16)
            ),
            cornerWidth: 28,
            cornerHeight: 28,
            transform: nil
        )

        let floorHeight = max(48, size.height * 0.12)
        floorRect = CGRect(x: 0, y: 0, width: size.width, height: floorHeight)
        floorNode.path = CGPath(rect: floorRect, transform: nil)

        hudNode.position = CGPoint(x: 16, y: size.height - 16)
        eventNode.position = CGPoint(x: 16, y: size.height - 36)
        helpNode.position = CGPoint(x: 16, y: 12)

        wallOffset = size.width * 0.72
        wallGapCenter = size.height * 0.55
        lowerWallRect = .zero
        upperWallRect = .zero
    }

    private func startRenderLoop() {
        renderTask?.cancel()
        renderTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let snapshot = await runtime.snapshot()
                self.render(snapshot)
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    private func render(_ snapshot: UrkelBirdSceneSnapshot) {
        syncGameplayKitPhase(snapshot.phase)

        let context = snapshot.context
        let playerX = size.width * UrkelBirdSceneVisual.playerXRatio
        let baseY = max(size.height * 0.22, size.height * 0.5)
        let y = baseY + CGFloat(context.altitude) * UrkelBirdSceneVisual.worldScale
        birdNode.position = CGPoint(x: playerX, y: y)
        let birdHitbox = makeBirdHitboxRect(center: birdNode.position, size: birdNode.size)
        birdHitboxNode.path = CGPath(rect: birdHitbox, transform: nil)
        if hasBirdTexture {
            birdNode.colorBlendFactor = snapshot.crashed ? 0.25 : 0
            birdNode.color = snapshot.crashed ? .systemRed : .clear
        } else {
            birdNode.colorBlendFactor = 1
            birdNode.color = snapshot.crashed ? .systemRed : .systemYellow
        }

        updateWalls(snapshot: snapshot, playerX: playerX)
        evaluateCollisionIfNeeded(snapshot: snapshot, birdHitbox: birdHitbox)

        let phase = snapshot.phase.rawValue.uppercased()
        let crash = context.crashReason.map { " crash: \($0)" } ?? ""
        hudNode.text = "[\(phase)] score: \(context.score) altitude: \(context.altitude) ticks: \(context.tickCount)\(crash)"
        hudNode.fontColor = snapshot.crashed ? .systemRed : .systemGreen

        if let event = snapshot.debugEvent {
            eventNode.text = "trigger: \(event.trigger) | \(event.from.rawValue) -> \(event.to.rawValue)"
        }
    }

    private func updateWalls(snapshot: UrkelBirdSceneSnapshot, playerX: CGFloat) {
        if snapshot.phase == .playing {
            wallOffset -= UrkelBirdSceneVisual.wallSpeedPerTick
            if wallOffset < -UrkelBirdSceneVisual.wallWidth {
                wallOffset = size.width + 120
                wallGapCenter = CGFloat.random(in: size.height * 0.35 ... size.height * 0.75)
            }
        }

        let wallX = wallOffset
        let gapHalf = UrkelBirdSceneVisual.gapHeight * 0.5

        let lowerHeight = max(20, wallGapCenter - gapHalf)
        let upperY = min(size.height - 20, wallGapCenter + gapHalf)
        let upperHeight = max(20, size.height - upperY)

        lowerWallRect = CGRect(
            x: wallX,
            y: 0,
            width: UrkelBirdSceneVisual.wallWidth,
            height: lowerHeight
        )
        leftWallNode.path = CGPath(rect: lowerWallRect, transform: nil)

        upperWallRect = CGRect(
            x: wallX,
            y: upperY,
            width: UrkelBirdSceneVisual.wallWidth,
            height: upperHeight
        )
        rightWallNode.path = CGPath(rect: upperWallRect, transform: nil)

        // Lightweight visual collision hint: if wall reaches player lane while in playing phase.
        if snapshot.phase == .playing, abs(wallX - playerX) < UrkelBirdSceneVisual.wallWidth * 0.7 {
            eventNode.fontColor = .systemOrange
        } else {
            eventNode.fontColor = .cyan
        }
    }

    private func makeBirdHitboxRect(center: CGPoint, size: CGSize) -> CGRect {
        let fullRect = CGRect(
            x: center.x - (size.width * 0.5),
            y: center.y - (size.height * 0.5),
            width: size.width,
            height: size.height
        )

        let insetX = min(size.width * UrkelBirdSceneVisual.birdHitboxInsetRatio, size.width * 0.35)
        let insetY = min(size.height * UrkelBirdSceneVisual.birdHitboxInsetRatio, size.height * 0.35)
        return fullRect.insetBy(dx: insetX, dy: insetY)
    }

    private func evaluateCollisionIfNeeded(snapshot: UrkelBirdSceneSnapshot, birdHitbox: CGRect) {
        guard snapshot.phase == .playing else {
            collisionRequestInFlight = false
            return
        }

        guard let reason = collisionReason(for: birdHitbox) else {
            collisionRequestInFlight = false
            return
        }

        guard !collisionRequestInFlight else { return }
        collisionRequestInFlight = true
        Task { [runtime] in
            await runtime.collide(reason: reason)
        }
    }

    private func collisionReason(for birdHitbox: CGRect) -> String? {
        if birdHitbox.minY <= floorRect.maxY {
            return "Hit the floor"
        }

        if birdHitbox.intersects(lowerWallRect) || birdHitbox.intersects(upperWallRect) {
            return "Hit a wall"
        }

        if birdHitbox.maxY >= size.height - 8 {
            return "Hit the ceiling"
        }

        return nil
    }

    private func syncGameplayKitPhase(_ phase: UrkelBirdPhase) {
        switch phase {
        case .ready:
            phaseMachine.enter(ReadyPhaseState.self)
        case .playing:
            phaseMachine.enter(PlayingPhaseState.self)
        case .crashed:
            phaseMachine.enter(CrashedPhaseState.self)
        }
    }

    private func configureBirdNode() {
        if let texture = makeBirdTexture() {
            hasBirdTexture = true
            birdNode.texture = texture

            let textureSize = texture.size()
            let aspectRatio = textureSize.height > 0 ? textureSize.width / textureSize.height : 1
            let width = min(120, max(32, UrkelBirdSceneVisual.birdDisplayHeight * aspectRatio))
            birdNode.size = CGSize(width: width, height: UrkelBirdSceneVisual.birdDisplayHeight)
            birdNode.colorBlendFactor = 0
            birdNode.color = .clear
        } else {
            hasBirdTexture = false
            birdNode.texture = nil
            birdNode.size = UrkelBirdSceneVisual.fallbackBirdSize
            birdNode.colorBlendFactor = 1
            birdNode.color = .systemYellow
        }
    }

    private func makeBirdTexture() -> SKTexture? {
        #if canImport(UIKit)
        if let image = UIImage(
            named: UrkelBirdAssets.jumpingSpriteName,
            in: .module,
            compatibleWith: nil
        ), let cgImage = image.cgImage {
            return SKTexture(cgImage: cgImage)
        }
        #elseif os(macOS)
        if
            let image = Bundle.module.image(forResource: NSImage.Name(UrkelBirdAssets.jumpingSpriteName)),
            let imageData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: imageData),
            let cgImage = bitmap.cgImage
        {
            return SKTexture(cgImage: cgImage)
        }
        #endif

        if let url = UrkelBirdAssets.jumpingSpriteURL {
            #if os(macOS)
            if
                let image = NSImage(contentsOf: url),
                let imageData = image.tiffRepresentation,
                let bitmap = NSBitmapImageRep(data: imageData),
                let cgImage = bitmap.cgImage
            {
                return SKTexture(cgImage: cgImage)
            }
            #elseif canImport(UIKit)
            if
                let image = UIImage(contentsOfFile: url.path),
                let cgImage = image.cgImage
            {
                return SKTexture(cgImage: cgImage)
            }
            #endif
        }
        return nil
    }
}
