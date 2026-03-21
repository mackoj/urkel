# FolderWatch

A type-safe dependency for observing file system changes in directories using the TypeState design pattern.

## Overview

`FolderWatch` is a standalone Swift package that provides compile-time guarantees for directory observation state management. It leverages:

- **TypeState Pattern**: States are types, not values - illegal operations are caught at compile time
- **Swift Dependencies**: Full integration with PointFree's Dependencies library
- **Move Semantics**: Noncopyable types with `consuming` functions prevent state reuse
- **Actor Isolation**: Thread-safe event streaming with proper Swift concurrency

The package uses a checked-in generated file, `Sources/FolderWatch/FolderWatchClient+Generated.swift`, which is produced by Urkel.

The package is configured locally via `urkel-config.json` at the package root, which keeps Urkel settings with the package and still applies to `Sources/FolderWatch/folderwatch.urkel` through config discovery.
Use the `UrkelGenerate` command plugin to write the generated file into `Sources/FolderWatch/` when the `.urkel` source changes:

```bash
swift package plugin --allow-writing-to-package-directory urkel-generate
```

The command plugin has write permission for the package directory, so it can update the checked-in generated file directly.

## Quick Start

```swift
import Dependencies
import FolderWatch

@Dependency(\.folderWatch) var folderWatch

// Create observer in Idle state
let idle = folderWatch.makeObserver(directoryURL)

// Start observing - transitions to Running state
let running = await idle.start()

// Access events (only available in Running state)
for try await event in await running.events {
  print("Event: \(event.kind) - \(event.file.name)")
}

// Stop observing - transitions to Stopped state
let stopped = await running.stop()
```

## Features

- ✅ **Type-safe state transitions** - compile-time enforcement
- ✅ **Dependency injection** - easily testable and swappable
- ✅ **Auto-debouncing** - 500ms debounce on events
- ✅ **SwiftUI-friendly** - works with `@Observable` and `@Dependency`
- ✅ **Platform-aware** - FSEvents on macOS, noop on Linux

## Platform Support

### macOS
Uses FSEvents API for efficient, real-time file system monitoring:
- Low overhead
- Kernel-level notifications
- Instant change detection

### Linux and Other Platforms
Watch mode is not supported on Linux (uses noop implementation).
The tool can still be built and run without watch functionality.

## Documentation

See the [full documentation](../../docs/FolderWatchDependency.md) for:
- Detailed usage examples
- Testing guide
- Combined state pattern
- Migration guide

## Integration

### In Your Package

Add to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/pointfreeco/swift-dependencies.git", from: "1.8.1"),
  .package(url: "https://github.com/apple/swift-async-algorithms.git", from: "1.0.0"),
],
targets: [
  .target(
    name: "YourTarget",
    dependencies: [
      .product(name: "FolderWatch", package: "token-processor"),
    ]
  )
]
```

### Initialization

The dependency is automatically initialized with the correct implementation based on platform:

- **macOS**: FSEvents-based implementation (efficient, real-time)
- **Linux**: Noop implementation (watch mode not supported)
- **Test**: Unimplemented by default (override in tests)
- **Preview**: No-op implementation

```swift
// Automatically gets platform-appropriate implementation
@Dependency(\.folderWatch) var folderWatch
```

## Testing

Override the dependency in tests:

```swift
import Testing
import Dependencies
import FolderWatch

@Test
func testFolderWatch() async throws {
  await withDependencies {
    $0.folderWatch = .mock(events: [
      DirectoryEvent(
        file: FileInfo(url: URL(fileURLWithPath: "/test/file.txt")),
        kind: .created
      )
    ])
  } operation: {
    @Dependency(\.folderWatch) var folderWatch
    
    let observer = folderWatch.makeObserver(URL(fileURLWithPath: "/test"))
    let running = await observer.start()
    
    var receivedEvents: [DirectoryEvent] = []
    for try await event in await running.events {
      receivedEvents.append(event)
    }
    
    #expect(receivedEvents.count == 1)
  }
}
```

## Requirements

- Swift 6.1+
- macOS 15+ (for FSEvents-based implementation and watch mode)
- Linux (build support only, watch mode not available)
- iOS 17+ (fallback to no-op)

## License

Same as parent package.
