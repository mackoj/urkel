import Foundation
import Dependencies

// MARK: - SomeFeature2 Runtime Builder

/// Runtime transition hooks used to construct a machine observer without editing generated code.
struct SomeFeature2ClientRuntime {
    typealias InitialContextBuilder = @Sendable () -> SomeFeature2StateRuntimeContext
    typealias StartTransition = @Sendable (SomeFeature2StateRuntimeContext) async throws -> SomeFeature2StateRuntimeContext
    typealias ErrorErrorTransition = @Sendable (SomeFeature2StateRuntimeContext, Error) async throws -> SomeFeature2StateRuntimeContext
    typealias StopTransition = @Sendable (SomeFeature2StateRuntimeContext) async throws -> SomeFeature2StateRuntimeContext
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

extension SomeFeature2Client {
    /// Builds a client factory from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: SomeFeature2ClientRuntime) -> Self {
        Self(
            makeSomeFeature2: {
                let context = runtime.initialContext()
                return SomeFeature2Machine<SomeFeature2StateIdle>(
                    internalContext: context,
                _start: runtime.startTransition,
                _errorError: runtime.errorErrorTransition,
                _stop: runtime.stopTransition
                )
            }
        )
    }
}

// MARK: - SomeFeature2 Client

/// Dependency client entry point for constructing SomeFeature2 state machines.
public struct SomeFeature2Client: Sendable {
    public var makeSomeFeature2: @Sendable () -> SomeFeature2Machine<SomeFeature2StateIdle>

    public init(makeSomeFeature2: @escaping @Sendable () -> SomeFeature2Machine<SomeFeature2StateIdle>) {
        self.makeSomeFeature2 = makeSomeFeature2
    }
}