import Foundation
import Dependencies

// MARK: - Live Implementations

extension SomeFeature1Client {
    public static func makeLive() -> Self {
        Self {
            SomeFeature1Machine<SomeFeature1StateIdle>(
                internalContext: SomeFeature1StateRuntimeContext(),
                _start: { ctx in ctx },
                _errorError: { ctx, _ in ctx },
                _stop: { ctx in ctx }
            )
        }
    }
}

extension SomeFeature2Client {
    public static func makeLive() -> Self {
        Self {
            SomeFeature2Machine<SomeFeature2StateIdle>(
                internalContext: SomeFeature2StateRuntimeContext(),
                _start: { ctx in ctx },
                _errorError: { ctx, _ in ctx },
                _stop: { ctx in ctx }
            )
        }
    }
}

extension MainFSMClient {
    public static func makeLive() -> Self {
        .fromRuntime(MainFSMClientRuntime(
            initialContext: { MainFSMStateRuntimeContext() },
            startTransition: { ctx in ctx },
            errorErrorTransition: { ctx, _ in ctx },
            stopTransition: { ctx in ctx },
            makeSomeFeature1: { SomeFeature1Client.makeLive().makeSomeFeature1() },
            makeSomeFeature2: { SomeFeature2Client.makeLive().makeSomeFeature2() }
        ))
    }
}
