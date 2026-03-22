import Foundation

// MARK: - Live Client

extension FolderWatchClient {
  #if canImport(FSEventsWrapper)
    /// A live folder watch client backed by `FSEvents` on supported Apple platforms.
    public static var live: Self {
      .fromRuntime(_runtime(implementation: .live))
    }
  #endif
}
