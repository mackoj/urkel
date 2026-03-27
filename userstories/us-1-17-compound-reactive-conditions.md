# US-1.17: Compound Reactive Conditions

## Objective

Allow `@on` subscriptions to require **multiple conditions simultaneously** — combining the parent machine's own current state with sub-machine states and/or parallel region states — so that a reaction fires only when the last missing condition falls into place.

## Background

Single-condition `@on` reactions (US-1.13, US-1.12) fire from any active parent state whenever the named external state is entered. This is often too broad.

The more common real-world need is a **join**: "react when BLE becomes `Connected`, but only while the parent is already in `Measuring`." Or: "start a session only once BLE is `Connected` AND the auth region is `Verified`." This is a multi-condition AND gate — all conditions must hold simultaneously before the reaction fires.

This concept maps to **synchronization bars** in Harel statecharts and **join transitions** in UML activity diagrams. The DSL expresses it with a comma-separated condition list on `@on`.

### Edge-triggered semantics

A compound condition is **edge-triggered**: it fires exactly once, at the moment the **last missing condition** becomes true while all others are already held. It does not re-fire as long as conditions remain stable.

```
@on BLE::Connected, Measuring -> measurementReady -> Idle
```

- Parent enters `Measuring` first, then `BLE` becomes `Connected` → **fires**
- `BLE` is already `Connected` when parent enters `Measuring` → **fires**
- Neither condition yet → **dormant**
- All conditions already held (no new edge) → **does not re-fire**

### What can appear in a condition list

The `,` operator is AND. Each term in the list is one of:

| Term | Meaning |
|------|---------|
| `StateName` (no `::`) | Parent machine is currently in this own state |
| `Machine::State` | Composed sub-machine (US-1.13) is in this state |
| `Parallel.Region::State` | Parallel region (US-1.12) is in this state |
| `Machine::final` | Sub-machine is in any final state |
| `Parallel::done` | All regions in the parallel block have completed |

## DSL Syntax

### Own state as a scope condition (most common)

```
machine HeartRate<HeartRateContext>

@import BLE
@import Sensor

@states
  init Off
  state Activating
  state Measuring
  state Idle
  state Error
  final Terminated

# Only react to BLE::Connected when the parent is already in Activating
@on BLE::Connected, Activating -> sensorReady -> Measuring

# Only react to Sensor::Error when measuring (not in other states)
@on Sensor::Error, Measuring -> sensorLost -> Error
```

### Multi-machine join (both sub-machines must be ready)

```
machine Scale<ScaleContext>

@import BLE
@import Sensor

@states
  init Booting
  state Ready
  state Weighing
  final Done

# Fire only when BOTH BLE is connected AND Sensor is calibrated
@on BLE::Connected, Sensor::Calibrated -> allSystemsReady -> Ready / logReadiness
```

### Own state + parallel region join

```
machine StreamingPlayer<PlayerContext>

@states
  init Idle
  state Buffering
  @parallel Session
    region Network
      init Connecting
      state Connected
    region Cache
      init Warming
      state Ready
  final Closed

# Fire only when in Buffering AND both regions are satisfied
@on Session.Network::Connected, Session.Cache::Ready, Buffering -> startPlayback -> Session
```

### Three-way join with action

```
@on BLE::Connected, Sensor::Calibrated, Authenticated -> launch -> Running / logLaunch
```

### Compound condition with guard

```
# All conditions must hold AND the guard must pass
@on BLE::Connected, Measuring [hasEnoughSignal] -> measurementReady -> Idle
```

### Compound condition with internal reaction (no state change)

```
# When BLE reconnects while actively measuring, log it but don't change state
@on BLE::Connected, Measuring -*> / logMeasurementResume
```

## Acceptance Criteria

* **Given** `@on BLE::Connected, Measuring -> measurementReady -> Idle`, **when** `BLE` enters `Connected` while the parent is in `Measuring`, **then** the reaction fires and the parent transitions to `Idle`.

* **Given** `@on BLE::Connected, Measuring -> measurementReady -> Idle`, **when** the parent enters `Measuring` while `BLE` is already in `Connected`, **then** the reaction fires — the condition is symmetric; order of satisfaction does not matter.

* **Given** all conditions are simultaneously satisfied but no new edge has fired (the state was already fully satisfied and nothing changed), **when** evaluated, **then** the reaction does **not** re-fire — it is edge-triggered, not level-triggered.

* **Given** a compound condition with an own-state term (`Measuring`) and the parent is **not** in `Measuring` when the external condition fires, **when** the external condition fires, **then** the reaction does not fire — it waits until the parent enters `Measuring`.

* **Given** a compound condition with two external machine states (`BLE::Connected, Sensor::Calibrated`), **when** one is satisfied but not the other, **then** the reaction is dormant; it fires the moment the second condition is satisfied.

* **Given** a compound condition with a guard (`@on BLE::Connected, Measuring [hasEnoughSignal]`), **when** all conditions hold but the guard returns `false`, **then** the reaction does not fire.

* **Given** a compound condition where any term references a state that does not exist in the named machine/region/own states, **when** validated, **then** an error is emitted identifying the unknown state.

* **Given** a compound condition where the parent machine is in a **final** state, **when** an external condition fires, **then** the reaction is a **no-op** — final parent states are terminal.

* **Given** a compound condition with a single term (`@on BLE::Connected -> Active`), **when** processed, **then** it is identical to a plain single-condition `@on` — no error, no warning.

* **Given** a compound condition with two or more own-state terms (`@on Measuring, Idle`), **when** validated, **then** an error is emitted: `"A compound condition may reference at most one own state — a machine cannot be in two states simultaneously"`.

* **Given** `@on BLE::Connected, Sensor::Connected` where `Sensor` is not declared via `@import`, **when** validated, **then** an error is emitted: `"'@on Sensor::...' references undeclared import 'Sensor'"`.

## Grammar

```ebnf
OnDecl          ::= "@on" ConditionList ("->" (Identifier "->")? Identifier ActionClause?
                                        | "-*>" ActionClause) GuardClause? Newline
ConditionList   ::= OnCondition ("," OnCondition)*
OnCondition     ::= OwnStateRef | MachineStateRef | ParallelStateRef | ParallelDoneRef
OwnStateRef     ::= Identifier                          # no "::" — own parent state
MachineStateRef ::= Identifier "::" StateRef
ParallelStateRef ::= Identifier "." Identifier "::" StateRef
ParallelDoneRef ::= Identifier "::" "done"
StateRef        ::= "init" | "final" | "*" | Identifier
```

The validator distinguishes `OwnStateRef` from `MachineStateRef` by the presence of `::`. An identifier with no `::` is resolved against the parent machine's own `@states`.

## Design notes and open questions

### Condition list order and readability
By convention, write own-state conditions **last** in the list (closest to the arrow), so the reaction reads like "when X happens, and we're in state Y, do Z":
```
# Preferred: external conditions first, own state last
@on BLE::Connected, Sensor::Calibrated, Measuring -> startSession -> Active

# Avoid: own state buried in the middle
@on Measuring, BLE::Connected, Sensor::Calibrated -> startSession -> Active
```
The validator does not enforce this order — it is a readability convention.

### Parameter passing
When a compound condition fires, the transition may need typed parameters (e.g., `measurementComplete(bpm: Int)`). The source of those parameters when the trigger is reactive (not caller-driven) is an **open design question**. Two candidate approaches:
1. Parameters are drawn from the sub-machine's state value at the moment the condition fires (requires sub-machines to expose typed state values to the parent).
2. Parameters are provided by a named action/handler declared between the condition and the destination: `@on BLE::Connected, Measuring -> extractBPM -> measurementComplete(bpm: Int) -> Idle`.

This story does not prescribe the resolution — a follow-up story should address typed value flow from sub-machine states to parent transitions.

### Interaction with `@on` wildcards
A compound condition with a wildcard term (`@on BLE::*, Measuring`) means "react to any BLE state change while in Measuring." This is valid but broad — use with care.
