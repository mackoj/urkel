import SpriteKit
import SwiftUI
import UrkelBird

private enum DemoVisual {
#if os(macOS)
    static let sceneBackground = NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.17, alpha: 1)
    static let corridorFill = NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.33, alpha: 1)
    static let corridorStroke = NSColor(calibratedRed: 0.26, green: 0.33, blue: 0.47, alpha: 1)
#else
    static let sceneBackground = UIColor(red: 0.08, green: 0.11, blue: 0.17, alpha: 1)
    static let corridorFill = UIColor(red: 0.16, green: 0.22, blue: 0.33, alpha: 1)
    static let corridorStroke = UIColor(red: 0.26, green: 0.33, blue: 0.47, alpha: 1)
#endif

    /// Normalized crop (x, y, w, h) of the central jumping character in the sprite sheet.
    static let jumpingCrop = CGRect(
        x: 0.4108664772727273,
        y: 0.4095052083333333,
        width: 0.16938920454545456,
        height: 0.525390625
    )
}

private struct UrkelBirdSnapshot: Sendable {
    var context: UrkelBirdContext
    var crashed: Bool
}

private actor UrkelBirdRuntime {
    enum Command: Sendable {
        case flap
        case reset
        case tick
        case stop
    }

    private let commands: AsyncStream<Command>
    private var continuation: AsyncStream<Command>.Continuation?
    private var loopTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var latest = UrkelBirdSnapshot(context: .init(), crashed: false)

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
            var didCollide = false
            await runtime.publish(context: state.context, crashed: state.isCrashed)

            for await command in stream {
                switch command {
                case .flap:
                    state = try! await state.flap()

                case .reset:
                    state = Self.makeInitialState()
                    tickAccumulator = 0
                    didCollide = false

                case .tick:
                    guard !state.isCrashed else {
                        let context = state.context
                        let crashed = state.isCrashed
                        await runtime.publish(context: context, crashed: crashed)
                        continue
                    }

                    state = try! await state.tick(deltaY: -1)
                    tickAccumulator += 1

                    if tickAccumulator >= 8 {
                        tickAccumulator = 0
                        state = try! await state.scorePipe()
                    }

                    if state.context.altitude <= -10, !didCollide {
                        didCollide = true
                        state = try! await state.collide(reason: "Hit the ground")
                    }

                case .stop:
                    return
                }

                let context = state.context
                let crashed = state.isCrashed
                await runtime.publish(context: context, crashed: crashed)
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

    func snapshot() -> UrkelBirdSnapshot {
        latest
    }

    private func publish(context: UrkelBirdContext, crashed: Bool) {
        latest = .init(context: context, crashed: crashed)
    }

    private func enqueue(_ command: Command) {
        continuation?.yield(command)
    }

    private static func makeInitialState() -> UrkelBirdState {
        let observer = UrkelBirdClient.simpleGame.makeGame()
        return UrkelBirdState(observer)
    }
}

@MainActor
final class UrkelBirdScene: SKScene {
    private let runtime: UrkelBirdRuntime
    private let birdNode = SKSpriteNode()
    private let corridorNode = SKShapeNode()
    private let hudNode = SKLabelNode(fontNamed: "Menlo")
    private let helpNode = SKLabelNode(fontNamed: "Menlo")
    private var renderTask: Task<Void, Never>?

    fileprivate init(size: CGSize, runtime: UrkelBirdRuntime) {
        self.runtime = runtime
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.backgroundColor = DemoVisual.sceneBackground
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    deinit {
        renderTask?.cancel()
    }

    override func didMove(to view: SKView) {
#if os(macOS)
        view.window?.makeFirstResponder(view)
#endif
        setupNodes()
        Task { [runtime] in
            await runtime.start()
        }
        startRenderLoop()
    }

    override func willMove(from view: SKView) {
        renderTask?.cancel()
        renderTask = nil
        Task { [runtime] in
            await runtime.stop()
        }
    }

    #if os(macOS)
    override func keyDown(with event: NSEvent) {
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
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        Task { [runtime] in
            await runtime.flap()
        }
    }
    #endif

    private func setupNodes() {
        corridorNode.fillColor = DemoVisual.corridorFill
        corridorNode.strokeColor = DemoVisual.corridorStroke
        corridorNode.lineWidth = 4
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
        addChild(corridorNode)

        birdNode.texture = makeBirdTexture()
        birdNode.setScale(0.09)
        birdNode.zPosition = 10
        addChild(birdNode)

        hudNode.fontSize = 14
        hudNode.horizontalAlignmentMode = .left
        hudNode.verticalAlignmentMode = .top
        hudNode.position = CGPoint(x: 16, y: size.height - 16)
        hudNode.zPosition = 20
        addChild(hudNode)

        helpNode.fontSize = 12
        helpNode.horizontalAlignmentMode = .left
        helpNode.verticalAlignmentMode = .bottom
        helpNode.position = CGPoint(x: 16, y: 12)
        helpNode.text = "Space: flap  |  R: restart"
        helpNode.fontColor = .white
        helpNode.zPosition = 20
        addChild(helpNode)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
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
        hudNode.position = CGPoint(x: 16, y: size.height - 16)
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

    private func render(_ snapshot: UrkelBirdSnapshot) {
        let context = snapshot.context
        let baseY = size.height * 0.5
        let y = baseY + CGFloat(context.altitude * 8)
        birdNode.position = CGPoint(x: size.width * 0.33, y: y)
        birdNode.colorBlendFactor = snapshot.crashed ? 0.25 : 0
#if os(macOS)
        birdNode.color = snapshot.crashed ? .systemRed : .clear
#else
        birdNode.color = snapshot.crashed ? .red : .clear
#endif

        let crash = context.crashReason.map { " crash: \($0)" } ?? ""
        hudNode.text = "score: \(context.score) altitude: \(context.altitude) ticks: \(context.tickCount)\(crash)"
        helpNode.text = snapshot.crashed
            ? "Crashed - press R to restart"
            : "Space: flap  |  R: restart"
#if os(macOS)
        hudNode.fontColor = snapshot.crashed ? .systemRed : .systemGreen
#else
        hudNode.fontColor = snapshot.crashed ? .red : .green
#endif
    }

    private func makeBirdTexture() -> SKTexture? {
        let full = SKTexture(imageNamed: "Sprites/jumping_sprite")
        return SKTexture(rect: DemoVisual.jumpingCrop, in: full)
    }
}

@MainActor
struct UrkelBirdGameView: View {
    @State private var scene: UrkelBirdScene = {
        let runtime = UrkelBirdRuntime()
        return UrkelBirdScene(size: CGSize(width: 900, height: 600), runtime: runtime)
    }()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .ignoresSafeArea()
    }
}

@MainActor
struct UrkelBirdPreviewHost: PreviewProvider {
    static var previews: some View {
        UrkelBirdGameView()
            .frame(width: 900, height: 600)
    }
}

#Preview {
    UrkelBirdGameView()
        .frame(minWidth: 900, minHeight: 600)
}
