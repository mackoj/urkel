import Foundation

// MARK: - Folder Watch Context

/// Stores the state needed to transition a folder watch observer between lifecycle phases.
///
/// The context is carried internally by `FolderWatchObserver` and is not intended to be
/// constructed directly by library consumers.
public struct FolderWatchContext: Sendable {
  // MARK: Storage

  enum Storage: Sendable {
    case idle(_IdleContext)
    case running(_RunningState)
    case stopped(_StoppedContext)
  }

  let storage: Storage

  init(storage: Storage) {
    self.storage = storage
  }

  // MARK: Factories

  static func idle(_ context: _IdleContext) -> Self {
    Self(storage: .idle(context))
  }

  static func running(_ state: _RunningState) -> Self {
    Self(storage: .running(state))
  }

  static func stopped(_ context: _StoppedContext) -> Self {
    Self(storage: .stopped(context))
  }
}
