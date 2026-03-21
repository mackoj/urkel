import Foundation

// MARK: - Test Helpers

extension FolderWatchClient {
  /// No-op implementation for previews and unimplemented platforms.
  public static var noop: Self {
    .fromRuntime(_runtime(implementation: .noop))
  }
  
  /// Creates a mock implementation that emits predefined events.
  ///
  /// Useful for testing and previews where you want to simulate file system events.
  ///
  /// - Parameter events: Array of events to emit
  /// - Returns: A mock folder watch client
  public static func mock(events: [DirectoryEvent]) -> Self {
    .fromRuntime(_runtime(implementation: .mock(events)))
  }
  
  /// Creates a mock implementation that fails with an error.
  ///
  /// - Parameter error: The error to throw
  /// - Returns: A failing folder watch client
  public static func failing(error: Error = DirectoryObserverError.observationFailed("Mock failure")) -> Self {
    let message = (error as? DirectoryObserverError).map(String.init(describing:)) ?? String(describing: error)
    return .fromRuntime(_runtime(implementation: .failing(message)))
  }
}
