# FolderWatch — Generated File in the New Model

This is a **reference sketch** of what `FolderWatchClient+Generated.swift` would look
like after the generator implements the sub-observer embedding design described in
`ClientStructureDesign.md`.

FolderWatch has **no `@compose`**, so the changes are minimal: dead code removed,
formatting standardised, doc-comments updated to reflect the ownership model.
This file is the **non-composed baseline** that every generated file shares; a composed
machine (e.g. BluetoohScale) extends it with the sub-observer slot described at the
bottom.

---

## What changes vs. today

| Today | New model |
|---|---|
| `FolderWatchRuntimeContext` struct generated | **Removed** — unused dead code |
| Inconsistent indentation in `fromRuntime` | Standardised |
| No doc-comment on `FolderWatchState` usage | Added concise usage comment |
| `withXxx` uses exhaustive `switch` | Uses `guard case let` (cleaner) |
| No mention of `~Escapable` | Documented as opt-in annotation |

---

## The file

```swift
import Foundation
import Dependencies

// MARK: - FolderWatch State Machine

/// Typestate markers for the `FolderWatch` machine.
/// These empty types are used solely as phantom parameters on `FolderWatchObserver<State>`.
public enum FolderWatchMachine {
    public enum Idle {}
    public enum Running {}
    public enum Stopped {}
}

// MARK: - FolderWatch Observer

/// A move-only, typestate-parameterised observer for the `FolderWatch` machine.
///
/// Each transition method is `consuming`: calling it transfers ownership of the
/// current observer to the method, which returns a new observer in the next state.
/// The old value cannot be used after the call — enforced at compile time by `~Copyable`.
///
/// **Structured-concurrency opt-in:** if the observer must not escape the task
/// in which it was created, conform it to `~Escapable` at the call site via a
/// local `borrowing` binding.  The generator does not add `~Escapable` automatically
/// because most callers (TCA reducers, ViewModels) need to store the combined
/// `FolderWatchState` across multiple actions.
public struct FolderWatchObserver<State>: ~Copyable {

    // Context is internal so transitions can update it without exposing mutation.
    var internalContext: FolderWatchContext

    // One closure per transition defined in the .urkel file.
    // All closures are `@Sendable` — they cross concurrency boundaries safely.
    let _start: @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    let _stop:  @Sendable (FolderWatchContext) async throws -> FolderWatchContext

    public init(
        internalContext: FolderWatchContext,
        _start: @escaping @Sendable (FolderWatchContext) async throws -> FolderWatchContext,
        _stop:  @escaping @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    ) {
        self.internalContext = internalContext
        self._start = _start
        self._stop  = _stop
    }

    /// Read-only access to the context without consuming the observer.
    public borrowing func withInternalContext<R>(
        _ body: (borrowing FolderWatchContext) throws -> R
    ) rethrows -> R {
        try body(internalContext)
    }
}

// MARK: - FolderWatch Runtime Stream

/// Generic async-stream helper used by generated runtime implementations.
/// Supports optional debounce (milliseconds).
actor FolderWatchRuntimeStream<Element: Sendable> {
    nonisolated let events: AsyncThrowingStream<Element, Error>

    private var continuation: AsyncThrowingStream<Element, Error>.Continuation?
    private var pendingEvent: Element?
    private var debounceTask: Task<Void, Never>?
    private let debounceMs: Int

    init(debounceMs: Int = 0) {
        self.debounceMs = max(0, debounceMs)
        var capturedContinuation: AsyncThrowingStream<Element, Error>.Continuation?
        self.events = AsyncThrowingStream<Element, Error> { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    func emit(_ event: Element) {
        guard let continuation else { return }
        if debounceMs == 0 {
            continuation.yield(event)
            return
        }
        pendingEvent = event
        debounceTask?.cancel()
        debounceTask = Task { [debounceMs] in
            try? await Task.sleep(nanoseconds: UInt64(debounceMs) * 1_000_000)
            self.flushPendingEvent()
        }
    }

    func finish(throwing error: Error? = nil) {
        debounceTask?.cancel()
        debounceTask = nil
        pendingEvent = nil
        continuation?.finish(throwing: error)
        continuation = nil
    }

    private func flushPendingEvent() {
        guard let event = pendingEvent else { return }
        pendingEvent = nil
        continuation?.yield(event)
    }
}

// MARK: - FolderWatch Runtime Builder

/// Bag of closures that fully describes the machine's runtime behaviour.
/// Developers fill this in their `XClient+Live.swift` and pass it to `fromRuntime(_:)`.
/// The generated code never touches this directly — it is an adapter only.
struct FolderWatchClientRuntime {
    typealias InitialContextBuilder = @Sendable (URL, Int) -> FolderWatchContext
    typealias StartTransition = @Sendable (FolderWatchContext) async throws -> FolderWatchContext
    typealias StopTransition  = @Sendable (FolderWatchContext) async throws -> FolderWatchContext

    let initialContext:  InitialContextBuilder
    let startTransition: StartTransition
    let stopTransition:  StopTransition
}

extension FolderWatchClient {
    /// Builds a `FolderWatchClient` from explicit runtime transition hooks.
    static func fromRuntime(_ runtime: FolderWatchClientRuntime) -> Self {
        Self(
            makeObserver: { directory, debounceMs in
                let context = runtime.initialContext(directory, debounceMs)
                return FolderWatchObserver<FolderWatchMachine.Idle>(
                    internalContext: context,
                    _start: runtime.startTransition,
                    _stop:  runtime.stopTransition
                )
            }
        )
    }
}

// MARK: - FolderWatch.Idle Transitions

extension FolderWatchObserver where State == FolderWatchMachine.Idle {
    /// Handles the `start` transition: Idle → Running.
    public consuming func start() async throws -> FolderWatchObserver<FolderWatchMachine.Running> {
        let nextContext = try await _start(internalContext)
        return FolderWatchObserver<FolderWatchMachine.Running>(
            internalContext: nextContext,
            _start: _start,
            _stop:  _stop
        )
    }
}

// MARK: - FolderWatch.Running Transitions

extension FolderWatchObserver where State == FolderWatchMachine.Running {
    /// Handles the `stop` transition: Running → Stopped.
    public consuming func stop() async throws -> FolderWatchObserver<FolderWatchMachine.Stopped> {
        let nextContext = try await _stop(internalContext)
        return FolderWatchObserver<FolderWatchMachine.Stopped>(
            internalContext: nextContext,
            _start: _start,
            _stop:  _stop
        )
    }
}

// MARK: - FolderWatch Combined State

/// A move-only enum that erases the typestate parameter so the full machine
/// lifecycle can be driven through a single `var`:
///
///     var state = FolderWatchState(client.makeObserver(url, 50))
///     state = try await state.start()
///     // … receive events from state.withRunning { $0.stream } …
///     state = try await state.stop()
///
/// Every transition method is `consuming`: ownership moves forward on each call.
/// Calling a transition while in an incompatible state is a no-op (returns self).
public enum FolderWatchState: ~Copyable {
    case idle(FolderWatchObserver<FolderWatchMachine.Idle>)
    case running(FolderWatchObserver<FolderWatchMachine.Running>)
    case stopped(FolderWatchObserver<FolderWatchMachine.Stopped>)

    public init(_ observer: consuming FolderWatchObserver<FolderWatchMachine.Idle>) {
        self = .idle(observer)
    }
}

// MARK: State inspection — borrowing, no ownership transfer

extension FolderWatchState {
    public borrowing func withIdle<R>(
        _ body: (borrowing FolderWatchObserver<FolderWatchMachine.Idle>) throws -> R
    ) rethrows -> R? {
        guard case let .idle(observer) = self else { return nil }
        return try body(observer)
    }

    public borrowing func withRunning<R>(
        _ body: (borrowing FolderWatchObserver<FolderWatchMachine.Running>) throws -> R
    ) rethrows -> R? {
        guard case let .running(observer) = self else { return nil }
        return try body(observer)
    }

    public borrowing func withStopped<R>(
        _ body: (borrowing FolderWatchObserver<FolderWatchMachine.Stopped>) throws -> R
    ) rethrows -> R? {
        guard case let .stopped(observer) = self else { return nil }
        return try body(observer)
    }
}

// MARK: Transitions — consuming, ownership moves forward

extension FolderWatchState {
    /// Attempts the `start` transition. No-ops when not in `.idle`.
    public consuming func start() async throws -> Self {
        switch consume self {
        case let .idle(observer):
            return .running(try await observer.start())
        case let .running(observer):
            return .running(observer)
        case let .stopped(observer):
            return .stopped(observer)
        }
    }

    /// Attempts the `stop` transition. No-ops when not in `.running`.
    public consuming func stop() async throws -> Self {
        switch consume self {
        case let .idle(observer):
            return .idle(observer)
        case let .running(observer):
            return .stopped(try await observer.stop())
        case let .stopped(observer):
            return .stopped(observer)
        }
    }
}

// MARK: - FolderWatch Client

/// Dependency-injection entry point for constructing FolderWatch observers.
/// Conforms to `DependencyKey` so it can be injected via the `Dependencies` library.
public struct FolderWatchClient: Sendable {
    public var makeObserver: @Sendable (URL, Int) -> FolderWatchObserver<FolderWatchMachine.Idle>

    public init(
        makeObserver: @escaping @Sendable (URL, Int) -> FolderWatchObserver<FolderWatchMachine.Idle>
    ) {
        self.makeObserver = makeObserver
    }
}

extension FolderWatchClient: DependencyKey {
    public static let testValue = Self(
        makeObserver: { _, _ in
            fatalError("Configure FolderWatchClient.testValue in tests.")
        }
    )

    public static let previewValue = Self(
        makeObserver: { _, _ in
            fatalError("Configure FolderWatchClient.previewValue in previews.")
        }
    )

    public static let liveValue = Self(
        makeObserver: { _, _ in
            fatalError("Configure FolderWatchClient.liveValue in your app target.")
        }
    )
}

extension DependencyValues {
    /// Accessor for the generated FolderWatchClient dependency.
    public var folderWatch: FolderWatchClient {
        get { self[FolderWatchClient.self] }
        set { self[FolderWatchClient.self] = newValue }
    }
}
```

---

## How a composed machine extends this baseline

For a machine with `@compose BLE`, the generator adds **three things** to the observer struct and **one section** to the combined state. Everything else above is unchanged.

### 1 — Sub-observer slot + factory in the observer

```swift
public struct ScaleObserver<State>: ~Copyable {
    var internalContext: ScaleContext

    // ── Added for @compose BLE ────────────────────────────────────────
    /// The embedded BLE machine state.
    /// `nil` before the `=> BLE.init` fork fires; non-nil afterwards.
    /// Ownership moves with every Scale transition automatically.
    var _bleState: BLEState?

    /// Factory called exactly once — by the fork transition — to create
    /// the initial BLE observer.  Carried through every transition so
    /// it is available even if the fork has not fired yet.
    let _makeBLE: @Sendable () -> BLEObserver<BLEMachine.Off>
    // ─────────────────────────────────────────────────────────────────

    // ... same transition closures as FolderWatch
    let _footTap: @Sendable (ScaleContext) async throws -> ScaleContext
    // ...
}
```

### 2 — Fork transition spawns BLE

```swift
// MARK: - Scale.WakingUp Transitions
extension ScaleObserver where State == ScaleMachine.WakingUp {
    /// FORK: Hardware initialised → Tare.  Simultaneously spawns the BLE machine.
    public consuming func hardwareReady() async throws -> ScaleObserver<ScaleMachine.Tare> {
        let nextCtx = try await _hardwareReady(internalContext)
        return ScaleObserver<ScaleMachine.Tare>(
            internalContext: nextCtx,
            _bleState: BLEState(_makeBLE()),  // ← BLE born here, lives inside Scale
            _makeBLE:  _makeBLE,
            _footTap:  _footTap,
            // ... carry all closures
        )
    }
}
```

### 3 — All subsequent transitions carry BLE forward

```swift
extension ScaleObserver where State == ScaleMachine.Tare {
    public consuming func zeroAchieved() async throws -> ScaleObserver<ScaleMachine.Weighing> {
        let nextCtx = try await _zeroAchieved(internalContext)
        return ScaleObserver<ScaleMachine.Weighing>(
            internalContext: nextCtx,
            _bleState: _bleState,   // ← moves with parent, zero extra cost
            _makeBLE:  _makeBLE,
            _footTap:  _footTap,
            // ...
        )
    }
}
```

### 4 — Combined state gets BLE-forwarding methods

```swift
// MARK: BLE event forwarding (generated for every BLE transition)
extension ScaleState {
    /// Forwards `powerOn` to the embedded BLE machine.
    /// No-ops if BLE has not been spawned yet (machine not yet at Tare).
    public consuming func blePowerOn() async throws -> Self {
        switch consume self {
        case var .tare(obs):
            // Partial consumption of a locally owned ~Copyable struct field:
            // valid in Swift 6.2 under SE-0390.
            var ble = consume obs._bleState
            obs._bleState = .none
            if let b = consume ble {
                obs._bleState = try await b.powerOn()
            }
            return .tare(obs)
        case var .weighing(obs):
            var ble = consume obs._bleState
            obs._bleState = .none
            if let b = consume ble { obs._bleState = try await b.powerOn() }
            return .weighing(obs)
        // … same pattern for .stabilized, .measuringImpedance, .syncing
        case let .off(obs):      return .off(obs)
        case let .wakingUp(obs): return .wakingUp(obs)
        case let .powerDown(obs): return .powerDown(obs)
        }
    }
    // bleScanTimeout(), bleDeviceDiscovered(device:), etc. follow the same pattern
}
```

### The call site — no orchestrator needed

```swift
var state = ScaleState(scaleClient.makeScale(makeBLE: bleClient.makeBLE))

state = try await state.footTap()
state = try await state.hardwareReady()      // BLE spawned inside state here
state = try await state.blePowerOn()         // BLE event
state = try await state.zeroAchieved()       // Scale event
state = try await state.bleDeviceDiscovered(device: found)
state = try await state.weightLocked(weight: 79.6)
state = try await state.syncData(payload: combined)  // Scale emits to BLE if configured
```

One variable. No actor. No `ScaleOrchestrator`. The state machine is its own coordinator.
