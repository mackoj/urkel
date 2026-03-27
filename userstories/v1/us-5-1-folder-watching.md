# US-5.1: Integrate Live Folder Watching (CLI)

## 1. Objective
Implement the `urkel watch` command in the CLI using the generated `FolderWatchClient` to automatically recompile `.urkel` files when they are saved.

## 2. Context
To provide a magical Developer Experience (DX), developers shouldn't have to manually run the generator every time they tweak a state machine. By eating our own dog food and using the `FolderWatchClient` (which Urkel is designed to generate), we can observe the `Sources` directory and rebuild the Typestate Swift files instantly upon a file save.

## 3. Acceptance Criteria
* **Given** the user runs `urkel watch ./Sources/Urkel --output ./Sources/Generated`.
* **When** the CLI starts.
* **Then** it performs an initial generation of all `.urkel` files in the input directory.
* **Given** the watcher is running.
* **When** the user modifies and saves `Bluetooth.urkel`.
* **Then** the CLI detects the `FSEvent`, parses, validates, and re-emits `Bluetooth+Generated.swift` automatically.

## 4. Implementation Details
* In `Urkel.swift` (the `swift-argument-parser` entry point), implement the `Watch` struct.
* Depend on the `FolderWatchClient` package.
* Initialize the observer: `let observer = folderWatch.makeObserver(inputURL, debounceMs: 300)`.
* `await observer.start()`.
* Setup a `for try await event in await observer.events` loop.
* Filter events: Only react to `.modified` or `.created` events where `event.file.url.pathExtension == "urkel"`.
* On valid events, pass the specific file URL to a coordinator that runs the `Parse -> Validate -> Emit` pipeline and writes the file.

## 5. Testing Strategy
* Because this relies heavily on the file system and FSEvents, this is best tested via an integration script rather than unit tests.
* Write a bash script that: Starts `urkel watch` in the background -> `touch test.urkel` -> asserts the generated `.swift` file appears -> kills the background process.