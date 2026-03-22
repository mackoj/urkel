import Testing
@testable import UrkelBird

private actor RuntimeCallCounter {
    private(set) var flap = 0
    private(set) var tick = 0
    private(set) var scorePipe = 0
    private(set) var collide = 0

    func markFlap() { flap += 1 }
    func markTick() { tick += 1 }
    func markScorePipe() { scorePipe += 1 }
    func markCollide() { collide += 1 }

    func snapshot() -> (flap: Int, tick: Int, scorePipe: Int, collide: Int) {
        (flap, tick, scorePipe, collide)
    }
}

@Suite("UrkelBird")
struct UrkelBirdTests {
    @Test("Simple game flow updates context and reaches crashed state")
    func simpleGameFlow() async throws {
        let observer = UrkelBirdClient.simpleGame.makeGame()
        let state = UrkelBirdState(observer)

        let playing1 = try await state.flap()
        #expect(playing1.withPlaying { $0.context.altitude } == 3)

        let playing2 = try await playing1.tick(deltaY: -1)
        #expect(playing2.withPlaying { $0.context.altitude } == 2)
        #expect(playing2.withPlaying { $0.context.tickCount } == 1)

        let playing3 = try await playing2.scorePipe()
        #expect(playing3.withPlaying { $0.context.score } == 1)

        let crashed = try await playing3.collide(reason: "pipe")
        #expect(crashed.withCrashed { $0.context.crashReason } == "pipe")
    }

    @Test("Custom runtime handlers are invoked by transitions")
    func runtimeHandlersAreInvoked() async throws {
        let counter = RuntimeCallCounter()
        let client = UrkelBirdClient.runtime(
            handlers: .init(
                onFlap: { _ in await counter.markFlap() },
                onTick: { _, _ in await counter.markTick() },
                onScorePipe: { _ in await counter.markScorePipe() },
                onCollide: { _, _ in await counter.markCollide() }
            )
        )

        let observer = client.makeGame()
        let playing = try await observer.flap()
        let afterTick = try await playing.tick(deltaY: -2)
        let afterScore = try await afterTick.scorePipe()
        _ = try await afterScore.collide(reason: "ground")

        let counts = await counter.snapshot()
        #expect(counts.flap == 1)
        #expect(counts.tick == 1)
        #expect(counts.scorePipe == 1)
        #expect(counts.collide == 1)
    }
}
