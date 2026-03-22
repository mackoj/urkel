import Foundation
import Testing
@testable import FolderWatch

private enum MockFailure: Error, CustomStringConvertible {
  case observation

  var description: String {
    "Mock failure"
  }
}

@Suite("FolderWatch")
struct FolderWatchTests {
  @Test("Mock observer emits expected events")
  func mockObserverEmitsExpectedEvents() async throws {
    let directory = URL(fileURLWithPath: "/tmp/folderwatch-tests/mock")
    let expectedEvents: [DirectoryEvent] = [
      DirectoryEvent(
        file: FileInfo(url: URL(fileURLWithPath: "/tmp/folderwatch-tests/mock/created.txt")),
        kind: .created
      ),
      DirectoryEvent(
        file: FileInfo(url: URL(fileURLWithPath: "/tmp/folderwatch-tests/mock/modified.txt")),
        kind: .modified
      ),
    ]

    let observer = FolderWatchClient.mock(events: expectedEvents).makeObserver(directory, 0)

    #expect(observer.directory == directory)

    let running = try await observer.start()
    #expect(running.directory == directory)

    let stream = await running.events
    var receivedEvents: [DirectoryEvent] = []

    for try await event in stream {
      receivedEvents.append(event)
    }

    #expect(receivedEvents == expectedEvents)

    let stopped = try await running.stop()
    #expect(stopped.directory == directory)
  }

  @Test("No-op observer finishes without events")
  func noopObserverFinishesWithoutEvents() async throws {
    let directory = URL(fileURLWithPath: "/tmp/folderwatch-tests/noop")
    let observer = FolderWatchClient.noop.makeObserver(directory, 0)

    let running = try await observer.start()
    let stream = await running.events

    var receivedEvents: [DirectoryEvent] = []
    for try await event in stream {
      receivedEvents.append(event)
    }

    #expect(receivedEvents.isEmpty)

    let stopped = try await running.stop()
    #expect(stopped.directory == directory)
  }

  @Test("Failing observer surfaces its error")
  func failingObserverSurfacesItsError() async throws {
    let directory = URL(fileURLWithPath: "/tmp/folderwatch-tests/failing")
    let expectedMessage = "Mock failure"
    let observer = FolderWatchClient.failing(error: MockFailure.observation).makeObserver(directory, 0)

    let running = try await observer.start()
    let stream = await running.events

    do {
      for try await _ in stream {}
      #expect(Bool(false), "Expected the stream to throw an observation error.")
    } catch let error as DirectoryObserverError {
      switch error {
      case .observationFailed(let message):
        #expect(message == expectedMessage)
      default:
        #expect(Bool(false), "Expected observationFailed, got \(error).")
      }
    } catch {
      #expect(Bool(false), "Expected DirectoryObserverError, got \(error).")
    }
  }
}
