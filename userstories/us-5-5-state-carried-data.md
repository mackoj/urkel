# US-5.5: State-Carried Data

## Objective

Emit typed read-only properties on non-terminal phases when a `state` declaration
carries parameters (US-1.19). State data is captured on entry and exposed as
`borrowing var` properties — accessible only in the matching phase, stored
internally in a private discriminated union that reuses the output-data slot
introduced in US-5.4.

## Input DSL

```
machine DataFetch: FetchContext

@states
  init Idle
  state Loading
  state Loaded(data: Data, source: URL)
  state Error(reason: String, code: Int)
  final(data: Data) Done

@transitions
  Idle    -> fetch(url: URL)                          -> Loading
  Loading -> fetchSuccess(data: Data, source: URL)    -> Loaded
  Loading -> fetchFailure(reason: String, code: Int)  -> Error
  Loaded  -> accept                                   -> Done
  Loaded  -> refetch(url: URL)                        -> Loading
  Error   -> retry(url: URL)                          -> Loading
  Error   -> dismiss                                  -> Idle
```

## Generated Output (delta)

The `_DataFetchStateData` enum covers ALL param-carrying states (including `final`):

```swift
private enum _DataFetchStateData: Sendable {
    case none
    case loaded(data: Data, source: URL)
    case error(reason: String, code: Int)
    case done(data: Data)
}
```

The transition into `Loaded` captures the data:

```swift
extension DataFetchMachine where Phase == DataFetchPhase.Loading {
    public consuming func fetchSuccess(
        data: Data, source: URL
    ) async throws -> DataFetchMachine<DataFetchPhase.Loaded> {
        let next = try await _fetchSuccess(_context, data, source)
        return DataFetchMachine<DataFetchPhase.Loaded>(
            _context: next,
            _stateData: .loaded(data: data, source: source),
            // … closures …
        )
    }
}
```

Properties are exposed on the constrained extension:

```swift
extension DataFetchMachine where Phase == DataFetchPhase.Loaded {
    /// The fetched data — available only in the `Loaded` phase.
    public borrowing var data: Data {
        guard case .loaded(let data, _) = _stateData else {
            preconditionFailure("Emitter invariant: expected .loaded, got \(_stateData)")
        }
        return data
    }

    public borrowing var source: URL {
        guard case .loaded(_, let source) = _stateData else {
            preconditionFailure("Emitter invariant: expected .loaded, got \(_stateData)")
        }
        return source
    }
}
```

When a transition LEAVES a param-carrying state (e.g., `Loaded -> accept -> Done`),
the next machine's `_stateData` is set to `.done(data: data)` if `Done` has
params, or `.none` otherwise. The outgoing transition event must supply the
`Done` params explicitly (per validator rule in US-1.19):

```swift
extension DataFetchMachine where Phase == DataFetchPhase.Loaded {
    public consuming func accept() async throws -> DataFetchMachine<DataFetchPhase.Done> {
        let next = try await _accept(_context)
        // `done` requires `data: Data` — validator ensures Loaded carries it.
        // The accept transition receives data from the source state's _stateData.
        guard case .loaded(let data, _) = _stateData else {
            preconditionFailure("Emitter invariant: accept called outside Loaded phase")
        }
        return DataFetchMachine<DataFetchPhase.Done>(
            _context: next,
            _stateData: .done(data: data),
            // … closures …
        )
    }
}
```

## Acceptance Criteria

* **Given** `state Loaded(data: Data, source: URL)`, **when** emitted, **then**
  `DataFetchMachine<DataFetchPhase.Loaded>` exposes `public borrowing var data:
  Data` and `public borrowing var source: URL`.

* **Given** `state Loading` with no params, **when** emitted, **then** no
  properties are generated on `DataFetchPhase.Loading`.

* **Given** a transition that leaves a param-carrying state towards a `final`
  state with params, **when** emitted, **then** the transition method reads from
  `_stateData` to populate the `Done` case.

* **Given** `final(data: Data) Done` and `state Loaded(data: Data, source: URL)`
  in the same machine, **when** emitted, **then** a single `_DataFetchStateData`
  enum covers both (per US-5.4 + US-5.5 sharing the same slot).

* **Given** the emitted output, **when** parsed, **then** no Swift parser errors.

## Implementation Details

- `_stateData` and `_outputData` from US-5.4 are unified into a single
  `_XxxStateData` field on the machine struct to minimise stored properties.
- The emitter determines the data enum cases by collecting all states (any kind)
  that declare params.
- `state` params are captured from the inbound transition's event params by
  **matching names**: if the event carries `data: Data` and the state declares
  `data: Data`, the emitter emits capture code; extra event params are dropped.

## Testing Strategy

* Snapshot-test `stateMachine` for the DataFetch fixture.
* Assert `borrowing var data: Data` on `DataFetchPhase.Loaded` extension.
* Assert no properties on `DataFetchPhase.Loading`.
* Construct a noop DataFetch machine, call `fetchSuccess(data:source:)`, assert
  `.data` and `.source` return the values provided.
* Assert the `accept()` method reads from `_stateData` and populates the
  `.done(data:)` case.
