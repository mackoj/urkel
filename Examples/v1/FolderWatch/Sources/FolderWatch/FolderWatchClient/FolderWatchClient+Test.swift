import Foundation

// MARK: - Test Helpers

extension FolderWatchClient {
    /// Creates a mock implementation that emits predefined events then finishes.
    public static func mock(events: [DirectoryEvent]) -> Self {
        Self(makeObserver: { directory, debounceMs in
            FolderWatchMachine<FolderWatchStateIdle>(
                directory: directory,
                debounceMs: debounceMs,
                startTransition: {
                    let (stream, continuation) = AsyncThrowingStream<DirectoryEvent, Error>.makeStream()
                    Task {
                        for event in events { continuation.yield(event) }
                        continuation.finish()
                    }
                    return _makeMockRunning(
                        directory: directory,
                        debounceMs: debounceMs,
                        stream: stream,
                        continuation: continuation
                    )
                }
            )
        })
    }

    /// Creates a mock implementation whose events stream immediately throws with `error`.
    public static func failing(error: Error = DirectoryObserverError.observationFailed("Mock failure")) -> Self {
        Self(makeObserver: { directory, debounceMs in
            FolderWatchMachine<FolderWatchStateIdle>(
                directory: directory,
                debounceMs: debounceMs,
                startTransition: {
                    _makeFailingRunning(directory: directory, debounceMs: debounceMs, error: error)
                }
            )
        })
    }
}

// MARK: - Helpers

private func _makeMockRunning(
    directory: URL,
    debounceMs: Int,
    stream: AsyncThrowingStream<DirectoryEvent, Error>,
    continuation: AsyncThrowingStream<DirectoryEvent, Error>.Continuation
) -> FolderWatchMachine<FolderWatchStateRunning> {
    FolderWatchMachine<FolderWatchStateRunning>(
        directory: directory,
        debounceMs: debounceMs,
        errorErrorTransition: { _ in
            _makeMockRunning(directory: directory, debounceMs: debounceMs, stream: stream, continuation: continuation)
        },
        stopTransition: {
            continuation.finish()
            return FolderWatchMachine<FolderWatchStateStopped>(directory: directory, debounceMs: debounceMs)
        },
        eventsAccessor: { stream }
    )
}

private func _makeFailingRunning(
    directory: URL,
    debounceMs: Int,
    error: Error
) -> FolderWatchMachine<FolderWatchStateRunning> {
    FolderWatchMachine<FolderWatchStateRunning>(
        directory: directory,
        debounceMs: debounceMs,
        errorErrorTransition: { _ in
            _makeFailingRunning(directory: directory, debounceMs: debounceMs, error: error)
        },
        stopTransition: { FolderWatchMachine<FolderWatchStateStopped>(directory: directory, debounceMs: debounceMs) },
        eventsAccessor: { AsyncThrowingStream { $0.finish(throwing: error) } }
    )
}
