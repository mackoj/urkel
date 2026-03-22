import Foundation

// MARK: - Live Client

extension FolderWatchClient {
    /// The live production implementation — calls `.live` on supported platforms.
    public static func makeLive() -> Self {
        #if canImport(FSEventsWrapper)
        return .fromRuntime(_runtime(implementation: .live))
        #else
        return Self(makeObserver: { _, _ in fatalError("FolderWatchClient.makeLive() is not supported on this platform.") })
        #endif
    }

  #if canImport(FSEventsWrapper)
    /// A live folder watch client backed by `FSEvents` on supported Apple platforms.
    public static var live: Self {
      .fromRuntime(_runtime(implementation: .live))
    }
  #endif
}
