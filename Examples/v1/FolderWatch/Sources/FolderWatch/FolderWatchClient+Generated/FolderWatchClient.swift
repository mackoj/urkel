import Foundation
import Dependencies

// MARK: - FolderWatch Client

/// Dependency client entry point for constructing FolderWatch state machines.
public struct FolderWatchClient: Sendable {
    public var makeObserver: @Sendable (URL, Int) -> FolderWatchMachine<FolderWatchStateIdle>

    public init(makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchMachine<FolderWatchStateIdle>) {
        self.makeObserver = makeObserver
    }

    /// No-op implementation that performs no real side effects.
    public static var noop: Self {
        Self(makeObserver: { directory, debounceMs in
            FolderWatchMachine<FolderWatchStateIdle>(
                directory: directory,
                debounceMs: debounceMs,
                startTransition: { FolderWatchMachine<FolderWatchStateRunning>(
                        directory: directory,
                        debounceMs: debounceMs,
                        errorErrorTransition: { _ in FolderWatchMachine<FolderWatchStateRunning>(
                                directory: directory,
                                debounceMs: debounceMs,
                                errorErrorTransition: { _ in fatalError("Noop does not support cyclic 'error' transition") },
                                stopTransition: { FolderWatchMachine<FolderWatchStateStopped>(
                                        directory: directory,
                                        debounceMs: debounceMs
                                    ) },
                                eventsAccessor: { AsyncThrowingStream { $0.finish() } }
                            ) },
                        stopTransition: { FolderWatchMachine<FolderWatchStateStopped>(
                                directory: directory,
                                debounceMs: debounceMs
                            ) },
                        eventsAccessor: { AsyncThrowingStream { $0.finish() } }
                    ) }
            )
        })
    }
}