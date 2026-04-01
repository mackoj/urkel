# US-5.6: Actions & Entry/Exit Hooks

## Objective

Emit injected action closures for `/ action` transition annotations and
`@entry`/`@exit` lifecycle declarations (US-1.7). Actions are separate from
context-transforming transition closures: they fire side effects (`async ->
Void`) and do not modify the context. Entry/exit hooks are composed into every
inbound/outbound transition respectively by the emitter.

## Input DSL

```
machine MediaPlayer: PlayerContext

@states
  init Idle
  state Loading
  state Playing
  state Paused
  final Stopped

@entry Loading / showSpinner
@exit  Loading / hideSpinner
@entry Playing / startAnalytics, resumeHeartbeat
@exit  Playing / stopAnalytics, pauseHeartbeat

@transitions
  Idle    -> load(url: URL)  -> Loading  / logLoadRequest
  Loading -> ready           -> Playing  / hideSpinner, trackPlayStart
  Playing -> pause           -> Paused
  Paused  -> resume          -> Playing
  Playing -> stop            -> Stopped  / logPlaybackComplete
  Paused  -> stop            -> Stopped  / logPlaybackComplete
```

## Generated Output (delta)

Action closures join the machine struct alongside transition closures:

```swift
public struct MediaPlayerMachine<Phase>: ~Copyable, Sendable {
    fileprivate let _context: PlayerContext

    // Transition closures
    fileprivate let _load:  @Sendable (PlayerContext, URL) async throws -> PlayerContext
    fileprivate let _ready: @Sendable (PlayerContext) async throws -> PlayerContext
    fileprivate let _pause: @Sendable (PlayerContext) async throws -> PlayerContext
    fileprivate let _resume: @Sendable (PlayerContext) async throws -> PlayerContext
    fileprivate let _stop:  @Sendable (PlayerContext) async throws -> PlayerContext

    // Action closures
    fileprivate let _showSpinner:      @Sendable (PlayerContext) async -> Void
    fileprivate let _hideSpinner:      @Sendable (PlayerContext) async -> Void
    fileprivate let _startAnalytics:   @Sendable (PlayerContext) async -> Void
    fileprivate let _resumeHeartbeat:  @Sendable (PlayerContext) async -> Void
    fileprivate let _stopAnalytics:    @Sendable (PlayerContext) async -> Void
    fileprivate let _pauseHeartbeat:   @Sendable (PlayerContext) async -> Void
    fileprivate let _logLoadRequest:   @Sendable (PlayerContext) async -> Void
    fileprivate let _trackPlayStart:   @Sendable (PlayerContext) async -> Void
    fileprivate let _logPlaybackComplete: @Sendable (PlayerContext) async -> Void
}
```

Entry/exit hooks are **inlined** into each relevant transition method by the
emitter — no separate invocation mechanism is generated:

```swift
extension MediaPlayerMachine where Phase == MediaPlayerPhase.Idle {
    /// load: Idle → Loading
    public consuming func load(url: URL) async throws -> MediaPlayerMachine<MediaPlayerPhase.Loading> {
        // @exit Idle — none declared
        // transition
        let next = try await _load(_context, url)
        // transition action
        await _logLoadRequest(next)
        // @entry Loading
        await _showSpinner(next)
        return MediaPlayerMachine<MediaPlayerPhase.Loading>(
            _context: next, /* … closures … */
        )
    }
}

extension MediaPlayerMachine where Phase == MediaPlayerPhase.Loading {
    public consuming func ready() async throws -> MediaPlayerMachine<MediaPlayerPhase.Playing> {
        // @exit Loading
        await _hideSpinner(_context)
        let next = try await _ready(_context)
        // transition actions
        await _hideSpinner(next)
        await _trackPlayStart(next)
        // @entry Playing
        await _startAnalytics(next)
        await _resumeHeartbeat(next)
        return MediaPlayerMachine<MediaPlayerPhase.Playing>(
            _context: next, /* … closures … */
        )
    }
}
```

**Firing order**: `@exit source` → `transition closure` → `/ transition actions`
→ `@entry destination`.

## Acceptance Criteria

* **Given** `@entry Loading / showSpinner` and a transition `Idle -> load -> Loading`,
  **when** emitted, **then** the generated `load()` method calls `_showSpinner`
  **after** the transition closure and **before** returning.

* **Given** `@exit Loading / hideSpinner` and a transition `Loading -> ready -> Playing`,
  **when** emitted, **then** the generated `ready()` method calls `_hideSpinner`
  **before** the transition closure.

* **Given** multiple actions on `@entry Playing / startAnalytics, resumeHeartbeat`,
  **when** emitted, **then** both are called **in declaration order** in each
  transition that enters `Playing`.

* **Given** the same action name in `@exit` and `/ action` (e.g., `hideSpinner`
  appears in both), **when** emitted, **then** it is deduplicated into a **single**
  closure property — not duplicated.

* **Given** a machine without any actions, **when** emitted, **then** no action
  closures are present in the machine struct (no dead code).

* **Given** `noop` in `XxxClient`, **when** constructed, **then** all action
  closures default to `{ _ in }` (no-ops).

## Implementation Details

- Collect all unique action names across `@entry`, `@exit`, and `/ action`
  annotations; deduplicate; generate one `fileprivate let` per unique name.
- In each transition method body, emit calls in the order: exit → transition →
  inline-action → entry.
- Action closures receive the **post-transition** context for `/ action` and
  `@entry`, and the **pre-transition** context for `@exit`.
- Action closures are `async -> Void` (not `throws`) because US-1.7 states
  actions cannot affect control flow. If an action needs to signal failure, the
  machine's context is the correct channel.

## Testing Strategy

* Snapshot-test `stateMachine` for the MediaPlayer fixture.
* Assert `_showSpinner` and `_hideSpinner` closures are in the struct.
* Assert the `load(url:)` body calls `_logLoadRequest`, then `_showSpinner`.
* Assert the `ready()` body calls `_hideSpinner` (exit), `_trackPlayStart`,
  then `_startAnalytics`, `_resumeHeartbeat` (entry).
* Verify deduplication: `hideSpinner` appears once as a closure property.
* Verify noop actions are `{ _ in }`.
