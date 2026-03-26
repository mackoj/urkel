import Foundation
import Dependencies

// MARK: - SomeFeature1 Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct SomeFeature1ClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> SomeFeature1StateRuntimeContext
    typealias StartTransition = @Sendable (SomeFeature1StateRuntimeContext) async throws -> SomeFeature1StateRuntimeContext
    typealias ErrorErrorTransition = @Sendable (SomeFeature1StateRuntimeContext, Error) async throws -> SomeFeature1StateRuntimeContext
    typealias StopTransition = @Sendable (SomeFeature1StateRuntimeContext) async throws -> SomeFeature1StateRuntimeContext
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

extension SomeFeature1Client {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: SomeFeature1ClientRuntime) -> Self {
        Self(
            makeSomeFeature1: {
                let context = runtime.initialContext()
                return SomeFeature1Machine<SomeFeature1StateIdle>(
                    internalContext: context,
                _start: runtime.startTransition,
                _errorError: runtime.errorErrorTransition,
                _stop: runtime.stopTransition
                )
            }
        )
    }
}

// MARK: - SomeFeature1 Client

/// Dependency client entry point for constructing SomeFeature1 state machines.
public struct SomeFeature1Client: Sendable {
    public var makeSomeFeature1: @Sendable () -> SomeFeature1Machine<SomeFeature1StateIdle>

    public init(makeSomeFeature1: @escaping @Sendable () -> SomeFeature1Machine<SomeFeature1StateIdle>) {
        self.makeSomeFeature1 = makeSomeFeature1
    }
}