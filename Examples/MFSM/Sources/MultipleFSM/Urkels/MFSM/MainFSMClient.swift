import Foundation
import Dependencies

// MARK: - MainFSM Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct MainFSMClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> MainFSMStateRuntimeContext
    typealias StartTransition = @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
    typealias ErrorErrorTransition = @Sendable (MainFSMStateRuntimeContext, Error) async throws -> MainFSMStateRuntimeContext
    typealias StopTransition = @Sendable (MainFSMStateRuntimeContext) async throws -> MainFSMStateRuntimeContext
    let initialContext: InitialContextBuilder
    let startTransition: StartTransition
    let errorErrorTransition: ErrorErrorTransition
    let stopTransition: StopTransition

    init(
        initialContext: @escaping InitialContextBuilder,
        startTransition: @escaping StartTransition,
        errorErrorTransition: @escaping ErrorErrorTransition,
        stopTransition: @escaping StopTransition
    ) {
        self.initialContext = initialContext
        self.startTransition = startTransition
        self.errorErrorTransition = errorErrorTransition
        self.stopTransition = stopTransition
    }
}

extension MainFSMClient {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: MainFSMClientRuntime) -> Self {
        Self(
            makeMainFSM: {
                let context = runtime.initialContext()
                return MainFSMMachine<MainFSMStateIdle>(
                    internalContext: context,
                _start: runtime.startTransition,
                _errorError: runtime.errorErrorTransition,
                _stop: runtime.stopTransition
                )
            }
        )
    }
}

// MARK: - MainFSM Client

/// Dependency client entry point for constructing MainFSM state machines.
public struct MainFSMClient: Sendable {
    public var makeMainFSM: @Sendable () -> MainFSMMachine<MainFSMStateIdle>

    public init(makeMainFSM: @escaping @Sendable () -> MainFSMMachine<MainFSMStateIdle>) {
        self.makeMainFSM = makeMainFSM
    }
}