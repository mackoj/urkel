# US-1.13: Machine Composition

## Objective

Allow a machine to declare dependencies on other machines, spawn them as parallel co-machines at a specific transition point, and **react to their state changes** — keeping all state spaces entirely separate while providing a clean channel for the parent to observe and respond to its sub-machines.

## Background

Some machines naturally drive other machines. A `Scale` machine, once its hardware is ready, needs a `BLE` machine to start syncing over Bluetooth. The two machines run side-by-side: the parent transitions through its own states, the sub-machine transitions through its own, and their state spaces never merge.

But spawning a sub-machine and then having no way to observe it is half a feature. The parent machine almost always needs to know when the sub-machine reaches certain milestones — when BLE becomes connected, when it errors, when it finalizes. Without a structured way to express this, developers end up with out-of-band callbacks that are invisible to the DSL, the visualizer, and the simulator.

Urkel models this with three cooperating constructs:

1. **`@import`** — declares that this machine depends on another named machine.
2. **Fork operator `=>`** — spawns the imported machine at its `init` state as part of a transition.
3. **`@on MachineName::StateRef`** — declares a reaction to the sub-machine entering a specific state; the parent transitions or fires an action in response.

The `::` separator in `@on` is intentional: it visually marks a **cross-machine boundary**, distinguishing it from `.` which navigates within a machine's own hierarchy (compound states, US-1.10).

## DSL Syntax

### Import and fork

```
machine Scale: ScaleContext

@import BLE                          # local: resolves BLE.urkel from sibling files
@import Analytics from AnalyticsKit  # external: resolves from the AnalyticsKit package

@states
  init Off
  state WakingUp
  state Tare
  state Weighing
  state Syncing
  final PowerDown

@transitions
  Off      -> footTap       -> WakingUp

  # Fork: Scale moves to Tare AND BLE is spawned at its init simultaneously
  WakingUp -> hardwareReady -> Tare => BLE.init

  Tare     -> zeroAchieved              -> Weighing
  Weighing -> weightLocked(weight: Double) -> Syncing
  Syncing  -> syncComplete              -> PowerDown
  Weighing -> userSteppedOff            -> PowerDown
```

### Reacting to sub-machine state changes (`@on`)

```
# When BLE reaches its Connected state, Scale moves to Syncing
@on BLE::Connected -> Syncing

# When BLE reaches any final state, Scale moves to PowerDown with an action
@on BLE::final -> PowerDown / logBLEShutdown

# When BLE enters its Error state, call an action then transition
@on BLE::Error -> handleBLEError -> WakingUp

# Internal reaction: BLE changed state but Scale stays put — just fire an action
@on BLE::Scanning -*> / logBLEScanning

# Wildcard: react to any BLE state change with an action, no parent state change
@on BLE::* -*> / traceBLETransition
```

### Full example combining fork and reactions

```
machine HeartRate: HeartRateContext

@import BLE

@states
  init Off
  state Activating
  state Idle
  state Measuring
  state SensorLost
  state Error
  final Terminated

# React to BLE sub-machine state changes
@on BLE::Connected -> Idle           # BLE is ready — HR sensor can now operate
@on BLE::Error     -> Error          / logBLEError
@on BLE::final     -> Terminated     / logBLEShutdown

@transitions
  Off        -> activate                         -> Activating => BLE.init
  Activating -> sensorReady                      -> Idle
  Activating -> sensorFailed(reason: String)     -> Error
  Idle       -> startMeasurement                 -> Measuring
  Measuring  -> measurementComplete(bpm: Int)    -> Idle
  Measuring  -> sensorContactLost                -> SensorLost
  SensorLost -> sensorContactRestored            -> Measuring
  SensorLost -> contactTimeout                   -> Error
  Error      -> reset                            -> Off
  Idle       -> deactivate                       -> Terminated
```

### `@on init` — reacting to a sub-machine restart

```
# If BLE resets and re-enters its init state, bring Scale back to WakingUp
@on BLE::init -> WakingUp / logBLEReset
```

## Acceptance Criteria

### `@import`

* **Given** `@import BLE`, **when** processed, **then** the machine resolves `BLE` from a sibling `.urkel` file named `BLE.urkel` in the same directory.

* **Given** `@import BLE from BLEKit`, **when** processed, **then** the machine resolves `BLE` from the `BLEKit` external package — not from sibling files.

* **Given** `@import BLE` where no sibling `BLE.urkel` exists, **when** validated, **then** an error is emitted: `"Cannot resolve local machine 'BLE' — expected 'BLE.urkel' in the same directory"`.

* **Given** `@import BLE from BLEKit` where `BLEKit` is not in the target's dependencies, **when** validated, **then** an error is emitted: `"Cannot find package 'BLEKit' in target dependencies"`.

* **Given** a duplicate `@import` for the same machine name, **when** validated, **then** an error is emitted: `"Duplicate import for machine 'BLE'"`.

* **Given** circular imports (`A @import B`, `B @import A`), **when** validated, **then** an error is emitted describing the cycle.

### Fork operator (`=>`)

* **Given** `=> BLE.init` on a transition where `BLE` is not declared via `@import`, **when** validated, **then** an error is emitted: `"Cannot fork undeclared machine 'BLE' — add '@import BLE'"`.

* **Given** a valid `=> BLE.init` fork, **when** the parent transition fires, **then** the parent moves to its destination state AND the `BLE` sub-machine starts at its `init` state simultaneously.

* **Given** a `final` source state on a fork transition, **when** validated, **then** an error is emitted: `"Transitions cannot originate from final states"`.

### `@on` subscriptions

* **Given** `@on BLE::Connected -> Active`, **when** the `BLE` sub-machine enters its `Connected` state, **then** the parent machine transitions to `Active`.

* **Given** `@on BLE::final -> Stopped`, **when** the `BLE` sub-machine enters **any** of its final states, **then** the parent transitions to `Stopped`. Multiple final states in `BLE` all trigger this reaction.

* **Given** `@on BLE::init -> WakingUp`, **when** the `BLE` sub-machine (re-)enters its `init` state, **then** the parent transitions to `WakingUp`.

* **Given** `@on BLE::* -*> / logChange`, **when** the `BLE` sub-machine enters **any** state, **then** the `logChange` action fires and the parent does not change its own state.

* **Given** `@on BLE::Error -> handleBLEError -> WakingUp`, **when** `BLE` enters `Error`, **then** the `handleBLEError` action fires and the parent transitions to `WakingUp`.

* **Given** an `@on` subscription and the parent machine is in a **final** state, **when** the sub-machine fires, **then** the reaction is a **no-op** — final parent states are terminal.

* **Given** an `@on` subscription and the `BLE` sub-machine has not yet been spawned (no `=> BLE.init` has fired), **when** the subscription would otherwise trigger, **then** it is **dormant** — subscriptions are only active after the corresponding fork.

* **Given** `@on BLE::UnknownState -> Active` where `UnknownState` is not in `BLE.urkel`'s `@states`, **when** validated, **then** an error is emitted: `"State 'UnknownState' does not exist in machine 'BLE'"`.

* **Given** `@on BLE::Connected -> UnknownState` where `UnknownState` is not in the parent's `@states`, **when** validated, **then** an error is emitted: `"Unknown destination state 'UnknownState'"`.

* **Given** `@on` referencing a machine not declared with `@import`, **when** validated, **then** an error is emitted: `"'@on BLE::...' references undeclared import 'BLE'"`.

* **Given** `@on BLE::*` alongside specific `@on BLE::Connected`, **when** the sub-machine enters `Connected`, **then** the specific subscription takes **precedence** over the wildcard (consistent with the specificity rules in US-1.8).

## Grammar

```ebnf
ImportDecl      ::= "@import" Identifier ("from" Identifier)? Newline
ForkClause      ::= "=>" Identifier ".init"
OnDecl          ::= "@on" MachineStateRef ("->" (Identifier "->")? Identifier ActionClause?
                                          | "-*>" ActionClause) Newline
MachineStateRef ::= Identifier "::" StateRef
StateRef        ::= "init" | "final" | "*" | Identifier
```

`ImportDecl` appears after the `machine` header and before `@states`. `OnDecl` entries appear at the top level alongside `@entry`/`@exit`, outside `@states` and `@transitions`.

## Notation summary

| Syntax | Meaning |
|--------|---------|
| `BLE::Connected` | `BLE` enters the `Connected` state |
| `BLE::init` | `BLE` (re-)enters its `init` state |
| `BLE::final` | `BLE` enters **any** of its final states (wildcard) |
| `BLE::*` | `BLE` enters **any** state (broad wildcard) |
| `@on BLE::X -> S` | Transition parent to `S` |
| `@on BLE::X -> S / a` | Action `a`, then transition parent to `S` |
| `@on BLE::X -> a -> S` | Named handler `a`, then transition parent to `S` |
| `@on BLE::X -*> / a` | Action `a`, parent stays in current state |

## Notes

- `@on` subscriptions are purely **reactive and non-interfering**: they observe the sub-machine's transitions and respond in the parent. They cannot prevent or modify the sub-machine's own transitions.
- `::` is reserved for cross-machine references in `@on`. `.` remains the separator for compound state hierarchy (US-1.10). The visual distinction is deliberate.
- `@on BLE::*` is a broad wildcard useful for cross-cutting concerns (tracing, logging). Prefer specific state subscriptions for all logic.
- The deprecated `@compose` keyword (alias for local `@import`) is still accepted with a deprecation warning but does not support `@on` — migrate to `@import` to use subscriptions.
