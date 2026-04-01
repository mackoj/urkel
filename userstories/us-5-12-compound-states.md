# US-5.12: Compound States

## Objective

Emit correct Swift code for hierarchical (compound) states (US-1.10). Each
compound state generates a nested phase sub-namespace, an inner state enum for
the sub-states, and transition extensions for both inner and outer transitions.
The parent machine's phase is the compound state itself; the active sub-state is
tracked in a second phantom type or (more pragmatically) via an embedded inner
`XxxInnerState` enum.

## Background

Compound states create a two-level hierarchy. The parent machine tracks which
compound state it is in; within that state, the sub-machine tracks which child is
active. The key constraint from US-1.10 is:

- Transitions **inside** the compound state are scoped to its sub-space.
- Transitions **on the parent** that target the compound state name descend to
  the compound state's `init` child.
- Transitions **on the parent** that target `CompoundState.ChildState` use dot
  notation.
- Transitions defined **on the parent at compound-state level** (e.g.,
  `Playing -> stop -> Stopped`) apply to **all children**.

## Input DSL

```
machine VideoPlayer: PlayerContext

@states
  init Idle
  state Playing @history {
    init Buffering
    state Streaming
    state Paused
  }
  final Stopped

@entry Playing.Streaming / startAnalytics
@exit  Playing.Streaming / stopAnalytics

@transitions
  Idle -> load(url: URL) -> Playing      # descends to Playing.Buffering

  Playing.Buffering -> bufferReady       -> Playing.Streaming
  Playing.Streaming -> pause             -> Playing.Paused
  Playing.Paused    -> resume            -> Playing.Streaming
  Playing.Streaming -> bufferUnderrun    -> Playing.Buffering

  Playing -> stop  -> Stopped            # parent-level: applies to all children
  Playing -> error -> Idle
```

## Generated Output (delta)

The compound state generates a nested phase namespace and inner state enum:

```swift
// MARK: - VideoPlayer Phases
public enum VideoPlayerPhase {
    public enum Idle {}
    public enum Playing {
        public enum Buffering {}
        public enum Streaming {}
        public enum Paused {}
    }
    public enum Stopped {}
}

// MARK: - Playing Inner State
public enum VideoPlayerPlayingState: ~Copyable {
    case buffering(VideoPlayerMachine<VideoPlayerPhase.Playing.Buffering>)
    case streaming(VideoPlayerMachine<VideoPlayerPhase.Playing.Streaming>)
    case paused(VideoPlayerMachine<VideoPlayerPhase.Playing.Paused>)
}
```

The machine struct carries the inner state when in `Playing`:

```swift
public struct VideoPlayerMachine<Phase>: ~Copyable, Sendable {
    fileprivate let _context: PlayerContext
    // Outer transition closures
    fileprivate let _load: @Sendable (PlayerContext, URL) async throws -> PlayerContext
    fileprivate let _stop: @Sendable (PlayerContext) async throws -> PlayerContext
    // Inner transition closures (scoped to Playing sub-space)
    fileprivate let _bufferReady:    @Sendable (PlayerContext) async throws -> PlayerContext
    fileprivate let _pause:          @Sendable (PlayerContext) async throws -> PlayerContext
    fileprivate let _resume:         @Sendable (PlayerContext) async throws -> PlayerContext
    fileprivate let _bufferUnderrun: @Sendable (PlayerContext) async throws -> PlayerContext
    // Inner state — only meaningful when Phase is Playing.*
    fileprivate var _playingInnerState: VideoPlayerPlayingState?
}
```

Transitions within the compound state use the inner state:

```swift
extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing.Buffering {
    public consuming func bufferReady() async throws
        -> VideoPlayerMachine<VideoPlayerPhase.Playing.Streaming>
    {
        await _startAnalytics(_context)            // @entry Streaming
        let next = try await _bufferReady(_context)
        return VideoPlayerMachine<VideoPlayerPhase.Playing.Streaming>(
            _context: next, /* closures */ _playingInnerState: nil
        )
    }
}
```

Parent-level transitions on the compound state generate methods on every child:

```swift
// Playing -> stop -> Stopped applies to all children
extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing.Buffering {
    public consuming func stop() async throws -> VideoPlayerMachine<VideoPlayerPhase.Stopped> { … }
}
extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing.Streaming {
    public consuming func stop() async throws -> VideoPlayerMachine<VideoPlayerPhase.Stopped> { … }
}
extension VideoPlayerMachine where Phase == VideoPlayerPhase.Playing.Paused {
    public consuming func stop() async throws -> VideoPlayerMachine<VideoPlayerPhase.Stopped> { … }
}
```

## Acceptance Criteria

* **Given** `state Playing { init Buffering; state Streaming; state Paused }`,
  **when** emitted, **then** `VideoPlayerPhase.Playing` is a nested enum with
  `Buffering`, `Streaming`, and `Paused` as inner enums.

* **Given** `Playing -> stop -> Stopped` (parent-level), **when** emitted, **then**
  `stop()` is generated on **all three** `Playing.*` extensions.

* **Given** `Idle -> load -> Playing` (targets compound state), **when** emitted,
  **then** the transition produces `VideoPlayerMachine<VideoPlayerPhase.Playing.Buffering>`
  (the `init` child of `Playing`).

* **Given** `@history` on `Playing`, **when** emitted, **then** an additional
  `Playing.History` pseudostate and a `VideoPlayerPlayingState` convenience are
  generated to support history restoration (see US-5.12 — History sub-story).

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- Detect compound states: `StateDecl.compound(CompoundStateDecl)`.
- Nested phase namespace: emit inner empty enums inside the compound's enum.
- Parent-level transitions on the compound state are expanded to one method per
  child via the emitter (not at parse time).
- `_playingInnerState` is `nil` outside `Playing.*` phases — the phantom type
  guarantees it is only accessed when relevant.

## Testing Strategy

* Snapshot-test the VideoPlayer fixture (compound + history).
* Assert `VideoPlayerPhase.Playing.Buffering` nested type exists.
* Assert `stop()` on all three `Playing.*` extensions.
* Assert `load(url:)` returns `VideoPlayerMachine<VideoPlayerPhase.Playing.Buffering>`.
