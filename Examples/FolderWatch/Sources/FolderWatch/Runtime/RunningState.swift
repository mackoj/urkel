import Foundation

#if canImport(FSEventsWrapper)
  import FSEventsWrapper
#endif

// MARK: - Running State

actor _RunningState {
    nonisolated let directory: URL
    nonisolated let events: AsyncThrowingStream<DirectoryEvent, Error>

    private let stream: FolderWatchRuntimeStream<DirectoryEvent>

    #if canImport(FSEventsWrapper)
        private var fsEventStream: FSEventStream?
    #endif

    init(directory: URL, debounceMs: Int) {
        self.directory = directory
        self.stream = FolderWatchRuntimeStream(debounceMs: debounceMs)
        self.events = stream.events
    }

    func emit(_ event: DirectoryEvent) async {
        await stream.emit(event)
    }

    func finish(throwing error: Error? = nil) async {
        await stream.finish(throwing: error)
    }

    func stop() async {
        #if canImport(FSEventsWrapper)
            fsEventStream?.stopWatching()
            fsEventStream = nil
        #endif
        await stream.finish()
    }

    #if canImport(FSEventsWrapper)
        func setFSEventStream(_ stream: FSEventStream) {
            fsEventStream = stream
        }
    #endif
}
