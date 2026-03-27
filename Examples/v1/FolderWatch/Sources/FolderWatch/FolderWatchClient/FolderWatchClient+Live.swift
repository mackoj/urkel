import Foundation

#if canImport(FSEventsWrapper)
  import FSEventsWrapper
#endif

// MARK: - Live Client

extension FolderWatchClient {
    /// The live production implementation using FSEvents on supported platforms.
    public static func makeLive() -> Self {
        #if canImport(FSEventsWrapper)
        return Self(makeObserver: { directory, debounceMs in
            FolderWatchMachine<FolderWatchStateIdle>(
                directory: directory,
                debounceMs: debounceMs,
                startTransition: {
                    let runningState = _RunningState(directory: directory, debounceMs: debounceMs)

                    let flags = FSEventStreamCreateFlags(
                        kFSEventStreamCreateFlagFileEvents
                            | kFSEventStreamCreateFlagNoDefer
                            | kFSEventStreamCreateFlagWatchRoot
                    )

                    guard let stream = FSEventStream(
                        path: directory.path,
                        fsEventStreamFlags: flags,
                        callback: { _, event in
                            Task { await _handleFSEvent(event, state: runningState) }
                        }
                    ) else {
                        await runningState.finish(
                            throwing: DirectoryObserverError.observationFailed(
                                "Unable to start FSEvents stream for \(directory.path)"
                            )
                        )
                        return _makeLiveRunning(directory: directory, debounceMs: debounceMs, runningState: runningState)
                    }

                    stream.startWatching()
                    await runningState.setFSEventStream(stream)

                    return _makeLiveRunning(directory: directory, debounceMs: debounceMs, runningState: runningState)
                }
            )
        })
        #else
        return Self(makeObserver: { _, _ in fatalError("FolderWatchClient.makeLive() is not supported on this platform.") })
        #endif
    }
}

#if canImport(FSEventsWrapper)
/// Creates a Running machine that stays alive through error events, reusing the given `runningState`.
private func _makeLiveRunning(
    directory: URL,
    debounceMs: Int,
    runningState: _RunningState
) -> FolderWatchMachine<FolderWatchStateRunning> {
    FolderWatchMachine<FolderWatchStateRunning>(
        directory: directory,
        debounceMs: debounceMs,
        errorErrorTransition: { _ in
            _makeLiveRunning(directory: directory, debounceMs: debounceMs, runningState: runningState)
        },
        stopTransition: {
            await runningState.stop()
            return FolderWatchMachine<FolderWatchStateStopped>(directory: directory, debounceMs: debounceMs)
        },
        eventsAccessor: { runningState.events }
    )
}

private func _handleFSEvent(_ event: FSEvent, state: _RunningState) async {
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
