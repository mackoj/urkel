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

    let running = await observer.start()
    #expect(running.directory == directory)

    let stream = running.events
    var receivedEvents: [DirectoryEvent] = []

    for try await event in stream {
      receivedEvents.append(event)
    }

    #expect(receivedEvents == expectedEvents)

    let stopped = await running.stop()
    #expect(stopped.directory == directory)
  }

  @Test("No-op observer finishes without events")
  func noopObserverFinishesWithoutEvents() async throws {
    let directory = URL(fileURLWithPath: "/tmp/folderwatch-tests/noop")
    let observer = FolderWatchClient.noop.makeObserver(directory, 0)

    let running = await observer.start()
    let stream = running.events

    var receivedEvents: [DirectoryEvent] = []
    for try await event in stream {
      receivedEvents.append(event)
    }

    #expect(receivedEvents.isEmpty)

    let stopped = await running.stop()
    #expect(stopped.directory == directory)
  }

  @Test("Failing observer surfaces its error via the events stream")
  func failingObserverSurfacesItsError() async throws {
    let directory = URL(fileURLWithPath: "/tmp/folderwatch-tests/failing")
    let expectedMessage = "Mock failure"
    let observer = FolderWatchClient.failing(error: MockFailure.observation).makeObserver(directory, 0)

    let running = await observer.start()

    do {
      for try await _ in running.events {}
      #expect(Bool(false), "Expected the events stream to throw an error.")
    } catch let error as MockFailure {
      #expect(error.description == expectedMessage)
    } catch {
      #expect(Bool(false), "Expected MockFailure, got \(error).")
    }
  }
}
