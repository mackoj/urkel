# US-1.2: Establish File I/O Pipeline

## 1. Objective
Implement the logic within the CLI's `generate` command to securely read a `.urkel` text file from the user's disk and write a placeholder `.swift` file to the specified output directory.

## 2. Context
Before integrating the Parser and Emitter, we must prove the CLI can interact with the file system safely. This story creates the "bread bun" of the compiler sandwich. It handles file resolution, directory creation (if the output directory doesn't exist), and basic string encoding operations.

## 3. Acceptance Criteria
* **Given** a valid path to an existing `Test.urkel` file and a valid output directory.
* **When** the `generate` command runs.
* **Then** it reads the contents of the file into memory and writes a `Test+Generated.swift` file containing a dummy string to the output directory.
* **Given** a path to a `.urkel` file that does not exist.
* **When** the command runs.
* **Then** it fails gracefully with a user-friendly error (e.g., "Error: File not found at path...").
* **Given** an output directory path that does not currently exist.
* **When** the command runs and attempts to write the generated file.
* **Then** the CLI automatically creates the intermediate directories before writing the file.

## 4. Implementation Details
* Inject `FileManager.default` operations into the `UrkelGenerator` (or directly in the `Generate` command for V1).
* Use `String(contentsOf: URL, encoding: .utf8)` to read the input.
* Use `FileManager.default.createDirectory(at:withIntermediateDirectories:attributes:)` to ensure the output destination exists.
* Construct the output URL by taking the input's `lastPathComponent`, stripping the `.urkel` extension, and appending `+Generated.swift`.
* Use `try dummyString.write(to: outputURL, atomically: true, encoding: .utf8)` to save the file.

## 5. Testing Strategy
* **Integration Tests:** Use a temporary directory (`FileManager.default.temporaryDirectory`). Create a mock `.urkel` file, run the file I/O function targeting another folder in the temp directory, and assert the output file exists and contains the dummy text.