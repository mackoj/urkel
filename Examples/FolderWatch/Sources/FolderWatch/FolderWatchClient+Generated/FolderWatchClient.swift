import Foundation
import Dependencies

// MARK: - FolderWatch Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct FolderWatchClientRuntime {
    typealias InitialContextBuilder = @Sendable (URL, Int) -> FolderWatchContext
    typealias StartTransition = @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    typealias StopTransition = @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    let initialContext: InitialContextBuilder
    let startTransition: StartTransition
    let stopTransition: StopTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        startTransition: @escaping StartTransition,
        stopTransition: @escaping StopTransition
    ) {
        self.initialContext = initialContext
        self.startTransition = startTransition
        self.stopTransition = stopTransition
    }
}

extension FolderWatchClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: FolderWatchClientRuntime) -> Self {
        Self(
            makeObserver: { directory, debounceMs in
                let context = runtime.initialContext(directory, debounceMs)
                return FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>(
                    internalContext: context,
                _start: runtime.startTransition,
                _stop: runtime.stopTransition
                )
            }
        )
    }
}

// MARK: - FolderWatch Client

/// Dependency client entry point for constructing FolderWatch state machines.
public struct FolderWatchClient: Sendable {
    public var makeObserver: @Sendable (URL, Int) -> FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>

    public init(makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchStateMachine<FolderWatchStateMachine.State.Idle>) {
        self.makeObserver = makeObserver
    }
}