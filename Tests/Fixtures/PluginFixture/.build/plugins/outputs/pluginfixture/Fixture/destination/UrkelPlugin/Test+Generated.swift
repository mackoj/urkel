import Foundation
import Dependencies

public enum Idle {}
public enum Running {}
public enum Stopped {}

public struct TestObserver<State>: ~Copyable {
    private var internalContext: Any

    private let _start: @Sendable (Any) async throws -> Any
    private let _stop: @Sendable (Any) async throws -> Any

    public init(
        internalContext: Any,
        _start: @escaping @Sendable (Any) async throws -> Any,
        _stop: @escaping @Sendable (Any) async throws -> Any
    ) {
        self.internalContext = internalContext

        self._start = _start
        self._stop = _stop
    }
}

extension TestObserver where State == Idle {
    public consuming func start() async throws -> TestObserver<Running> {
        let nextContext = try await self._start(self.internalContext)
        return TestObserver<Running>(
            internalContext: nextContext,
                _start: self._start,
                _stop: self._stop
        )
    }
}

extension TestObserver where State == Running {
    public consuming func stop() async throws -> TestObserver<Stopped> {
        let nextContext = try await self._stop(self.internalContext)
        return TestObserver<Stopped>(
            internalContext: nextContext,
                _start: self._start,
                _stop: self._stop
        )
    }
}

public struct TestClient: Sendable {
    public var makeObserver: @Sendable () -> TestObserver<Idle>

    public init(makeObserver: @escaping @Sendable () -> TestObserver<Idle>) {
        self.makeObserver = makeObserver
    }
}

extension TestClient: TestDependencyKey {
    public static let testValue = Self(
        makeObserver: { 
            fatalError("Configure TestClient.testValue in tests.")
        }
    )
}

extension DependencyValues {
    public var test: TestClient {
        get { self[TestClient.self] }
        set { self[TestClient.self] = newValue }
    }
}