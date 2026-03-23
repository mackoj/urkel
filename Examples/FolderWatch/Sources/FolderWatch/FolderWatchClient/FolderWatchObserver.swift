import Foundation

#if canImport(FSEventsWrapper)
  import FSEventsWrapper
#endif

// MARK: - Runtime Observer Construction

extension FolderWatchMachine where State == FolderWatchStateRunning {
  /// The stream of directory events emitted while the observer is running.
  public var events: AsyncThrowingStream<DirectoryEvent, Error> {
    get async {
      self.withInternalContext { context in
        guard case let .running(runningState) = context.storage else {
          return AsyncThrowingStream { continuation in
            continuation.finish(
              throwing: DirectoryObserverError.observationFailed("Invalid running context for events.")
            )
          }
        }
        return runningState.events
      }
    }
  }
}

extension FolderWatchMachine {
  /// The directory currently associated with this observer.
  public var directory: URL {
    self.withInternalContext { context in
      guard let directory = FolderWatchClient._directory(from: context) else {
        preconditionFailure("FolderWatchObserver context does not contain a directory.")
      }
      return directory
    }
  }
}
