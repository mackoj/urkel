import Foundation

#if canImport(FSEventsWrapper)
  import FSEventsWrapper
#endif

// MARK: - Runtime Observer Construction

extension FolderWatchClient {
  static func _runtime(
    implementation: _FolderWatchImplementation
  ) -> FolderWatchClientRuntime {
    FolderWatchClientRuntime(
      initialContext: { directory, debounceMs in
        let initialContext = _IdleContext(
          directory: directory,
          debounceMs: debounceMs,
          implementation: implementation
        )
        return .idle(initialContext)
      },
      startTransition: { context in
        try await _startContext(context)
      },
      stopTransition: { context in
        try await _stopContext(context)
      }
    )
  }

  // MARK: Context Transitions

  private static func _startContext(_ context: FolderWatchContext) async throws -> FolderWatchContext {
    guard case let .idle(idleContext) = context.storage else {
      throw DirectoryObserverError.observationFailed("Invalid start context for FolderWatchObserver.")
    }

    let runningState = _RunningState(
      directory: idleContext.directory,
      debounceMs: idleContext.debounceMs
    )

    switch idleContext.implementation {
    case .noop:
      await runningState.finish()

    case .mock(let events):
      Task {
        for event in events {
          await runningState.emit(event)
        }
        await runningState.finish()
      }

    case .failing(let message):
      await runningState.finish(throwing: DirectoryObserverError.observationFailed(message))

    #if canImport(FSEventsWrapper)
      case .live:
        let flags = FSEventStreamCreateFlags(
          kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
            | kFSEventStreamCreateFlagWatchRoot
        )

        guard let stream = FSEventStream(
          path: idleContext.directory.path,
          fsEventStreamFlags: flags,
          callback: { _, event in
            Task {
              await _handleFSEvent(event, state: runningState)
            }
          }
        ) else {
          await runningState.finish(
            throwing: DirectoryObserverError.observationFailed(
              "Unable to start FSEvents stream for \(idleContext.directory.path)"
            )
          )
          return .running(runningState)
        }

        stream.startWatching()
        await runningState.setFSEventStream(stream)
    #endif
    }

    return .running(runningState)
  }

  private static func _stopContext(_ context: FolderWatchContext) async throws -> FolderWatchContext {
    if case let .running(runningState) = context.storage {
      let directory = runningState.directory
      await runningState.stop()
      return .stopped(_StoppedContext(directory: directory))
    }

    if case let .idle(idleContext) = context.storage {
      return .stopped(_StoppedContext(directory: idleContext.directory))
    }

    if case let .stopped(stoppedContext) = context.storage {
      return .stopped(stoppedContext)
    }

    throw DirectoryObserverError.observationFailed("Invalid stop context for FolderWatchObserver.")
  }

  // MARK: Directory Lookup

  static func _directory(from context: FolderWatchContext) -> URL? {
    if case let .idle(idleContext) = context.storage {
      return idleContext.directory
    }
    if case let .running(runningState) = context.storage {
      return runningState.directory
    }
    if case let .stopped(stoppedContext) = context.storage {
      return stoppedContext.directory
    }
    return nil
  }

  // MARK: FSEvents Bridging

  #if canImport(FSEventsWrapper)
    private static func _handleFSEvent(_ event: FSEvent, state: _RunningState) async {
      func fileInfo(for path: String) -> FileInfo {
        FileInfo(url: URL(fileURLWithPath: path))
      }

      switch event {
      case .itemCreated(let path, _, _, _):
        await state.emit(DirectoryEvent(file: fileInfo(for: path), kind: .created))

      case .itemRemoved(let path, _, _, _):
        await state.emit(DirectoryEvent(file: fileInfo(for: path), kind: .deleted))

      case .itemDataModified(let path, _, _, _),
        .itemInodeMetadataModified(let path, _, _, _),
        .itemFinderInfoModified(let path, _, _, _),
        .itemOwnershipModified(let path, _, _, _),
        .itemXattrModified(let path, _, _, _):
        await state.emit(DirectoryEvent(file: fileInfo(for: path), kind: .modified))

      case .itemRenamed(let path, _, _, _):
        await state.emit(DirectoryEvent(file: fileInfo(for: path), kind: .renamed))

      default:
        break
      }
    }
  #endif
}
