import Foundation

#if canImport(FSEventsWrapper)
  import FSEventsWrapper
#endif

// MARK: - Runtime Observer Construction

extension FolderWatchState {
  /// Starts the observer if it is currently idle.
  public consuming func startIfIdle() async throws -> Self {
    try await self.start()
  }

  /// Stops the observer if it is currently running.
  public consuming func stopIfRunning() async throws -> Self {
    try await self.stop()
  }

  /// The active event stream when the observer is running.
  public var events: AsyncThrowingStream<DirectoryEvent, Error>? {
    get async {
      switch self {
      case let .running(observer):
        return await observer.events
      case .idle:
        return nil
      case .stopped:
        return nil
      }
    }
  }

  /// The directory currently associated with the observer state.
  public var directory: URL {
    switch self {
    case let .idle(observer):
      return observer.directory
    case let .running(observer):
      return observer.directory
    case let .stopped(observer):
      return observer.directory
    }
  }
}
