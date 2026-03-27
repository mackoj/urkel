# Urkel DSL Construct Map — Superseded

This file has been merged into [CONSTRUCTS.md](CONSTRUCTS.md).

---

## Caller-Driven Transitions

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> event -> Dest` | Caller | Specific state | New state |
| `State -> event [guard] -> Dest` | Caller | Specific state | New state (conditional) |
| `State -> event -> Dest / action` | Caller | Specific state | New state + side effect |
| `State -*> event / action` | Caller | Specific state | In-place, no lifecycle |
| `* -> event -> Dest` ◆ | Caller | Any non-final state | New state |
| `* -*> event / action` ◆ | Caller | Any non-final state | In-place, no lifecycle |

`*` is sugar — expands to one explicit transition per non-final source state.  
`-*>` is an **effect modifier**, not a transition type: no exit/re-entry, no lifecycle firing, no timer reset.

---

## Automatic (fires on state entry, no caller)

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> always [guard] -> Dest` | Entry | Specific state | New state (conditional) |
| `State -> always -> Dest` | Entry | Specific state | New state (transient, unconditional) |
| `State -*> always [guard] / action` | Entry | Specific state | In-place side effect |
| `@entry State / action` | Any entry to state | All inbound transitions | Side effect (lifecycle) |
| `@exit State / action` | Any exit from state | All outbound transitions | Side effect (lifecycle) |

`@entry`/`@exit` are **not** sugar for per-transition actions — they do not fire on `-*>` internal transitions, which makes them semantically distinct.

---

## Timer

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> after(Ns) -> Dest` | Timer (auto-cancels on exit) | Specific state | New state |

Supported units: `ms`, `s`, `min`. Cannot be expressed with any other construct.

---

## Reactive (sub-machine / region state change)

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `@on Mach::State -> Dest` | Sub-machine enters state | Any parent state | New state |
| `@on Mach::State -*> / action` | Sub-machine enters state | Any parent state | In-place, no lifecycle |
| `@on Mach::init -> Dest` | Sub-machine (re-)enters init | Any parent state | New state |
| `@on Mach::final -> Dest` ◆ | Sub-machine enters any final | Any parent state | New state |
| `@on Mach::* -*> / action` ◆ | Any sub-machine state change | Any parent state | In-place, no lifecycle |
| `@on P.Region::State -> Dest` | Parallel region enters state | Any parent state | New state |
| `@on P.Region::State -*> / action` | Parallel region enters state | Any parent state | In-place, no lifecycle |
| `@on P::done -> Dest` ◆ | All regions reach final | Any parent state | New state |
| `@on X, OwnState -> Dest` | Sub-machine + own state (AND) | Specific parent state | New state |

`::` separates machine/region path from state name.  
`.` navigates within a machine's own hierarchy (compound states).  
`::final` and `P::done` are sugar — equivalent to explicitly listing each final state.

---

## Composition

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> event -> Dest => Mach.init` | Caller | Specific state | New state + spawns sub-machine |

The fork `=>` is an additional side effect on a regular transition, not a separate construct.

---

## Structural Declarations

These are not transitions — they modify the shape of states or the machine's contract.

| Construct | Purpose |
|-----------|---------|
| `init(params) StateName` | Typed construction-time inputs (US-1.3) |
| `final StateName(params)` | Typed terminal output value (US-1.5) |
| `State @history` | Shallow history — restore last direct child on re-entry (US-1.11) |
| `State @history(deep)` | Deep history — restore full active subtree on re-entry (US-1.11) |
| `State.History` as target | Navigate to history pseudostate of a compound state (US-1.11) |
| `@parallel Name` / `region R` | Declare orthogonal regions (US-1.12) |
| `@import Mach` / `@import Mach from Pkg` | Declare sub-machine dependency (US-1.13) |

---

## Primitive vs. Sugar Summary

| Category | Primitive (unique semantic) | Sugar (◆) |
|----------|-----------------------------|-----------|
| Caller-driven | `->`, `[guard]`, `-*>`, `/action` | `*` wildcard |
| Automatic | `always`, `@entry`, `@exit` | — |
| Timer | `after()` | — |
| Reactive | `@on ::State`, `@on X,S` | `::final`, `P::done`, `::*` |
| Composition | `=>` fork | — |

**Key insight:** `-*>` is a single **effect modifier** that appears across all trigger types (caller, `always`, `@on`). `*` is a **scope modifier** that applies only to caller-driven transitions (`@on` already has implicit any-state scope).
