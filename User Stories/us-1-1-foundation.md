# US-1.1: CLI Foundation & Architecture

## 1. Objective
Initialize the Swift package and establish the command-line interface (CLI) entry point using Apple's `swift-argument-parser`. Define the primary commands: `generate` and `watch`.

## 2. Context
Before we can parse text or generate Swift code, we need a vehicle to execute our logic. By setting up the SPM (Swift Package Manager) executable and the Argument Parser, we create the skeleton of the compiler. This ensures that when a developer types `urkel` in their terminal, the tool routes the arguments to the correct underlying systems.

## 3. Acceptance Criteria
* **Given** the user navigates to the built executable.
* **When** they run `urkel --help`.
* **Then** the terminal outputs the abstract for the tool and lists the available subcommands (`generate` and `watch`).
* **Given** the user runs `urkel generate ./Bluetooth.urkel --output ./Generated`.
* **When** the command executes.
* **Then** the `Generate` struct successfully captures `./Bluetooth.urkel` as the input argument and `./Generated` as the output option.
* **Given** the user runs `urkel watch ./Sources --output ./Generated`.
* **When** the command executes.
* **Then** the `Watch` struct successfully captures `./Sources` as the input argument and `./Generated` as the output option.

## 4. Implementation Details
* Run `swift package init --type executable --name Urkel` in the project root.
* Modify `Package.swift` to include `.package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")`.
* Create `Urkel.swift` as the `@main` entry point conforming to `AsyncParsableCommand`.
* Define the routing configuration: `static let configuration = CommandConfiguration(...)`.
* Create two nested structs conforming to `AsyncParsableCommand`: `Generate` and `Watch`.
* Add `@Argument var input: String` and `@Option var output: String` to both commands.
* For V1, the `run() async throws` methods should just `print()` the captured variables to prove the routing works.

## 5. Testing Strategy
* **Integration Tests:** Compile the executable via `swift build`. Write a simple bash script to invoke the binary with various flags (`--help`, missing arguments) to ensure the Argument Parser behaves exactly as expected and fails gracefully when required arguments are missing.