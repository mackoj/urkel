# Urkel DSL Constructs Reference

All constructs in the Urkel DSL mapped on three axes: **what triggers it**, **which source states it covers**, and **what it produces**.

> ◆ = syntactic sugar — equivalent to other constructs, but more ergonomic  
> ─ = structural declaration — not a transition

---

## Caller-driven transitions

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> event -> Dest` | Caller | Specific state | New state |
| `State -> event [guard] -> Dest` | Caller | Specific state | New state (conditional) |
| `State -> event -> Dest / action` | Caller | Specific state | New state + side effect |
| `State -*> event(params) / action` | Caller | Specific state | In-place, no lifecycle |
| `State -*> event(params)` | Machine-internal | Specific state | **Output event** → stream |
| `* -> event -> Dest` ◆ | Caller | Any non-final | New state |
| `* -*> event / action` ◆ | Caller | Any non-final | In-place, no lifecycle |

`*` is syntactic sugar — expands to one transition per non-final source state. See [US-1.18](us-1-18-wildcard-source.md).  
`-*>` has **two forms**: with `/action` = caller-driven in-place handler; without action = output event declaration (machine emits to caller; generator creates a stream). See [US-1.8](us-1-8-internal-and-wildcard-transitions.md), [US-1.16](us-1-16-continuation-transitions.md).

---

## Automatic transitions (fire on state entry, no caller)

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> always [guard] -> Dest` | State entry | Specific state | New state (conditional) |
| `State -> always -> Dest` | State entry | Specific state | New state (transient, unconditional) |
| `State -*> always [guard] / action` | State entry | Specific state | In-place side effect |
| `@entry State / action` | Any entry to state | All inbound transitions | Side effect (lifecycle) |
| `@exit State / action` | Any exit from state | All outbound transitions | Side effect (lifecycle) |

`@entry`/`@exit` are **not** sugar for per-transition actions — they do not fire on `-*>` internal transitions, which makes them semantically distinct. See [US-1.7](us-1-7-actions.md), [US-1.9](us-1-9-eventless-transitions.md).

---

## Timer

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> after(Ns) -> Dest` | Timer (auto-cancels on exit) | Specific state | New state |

Duration units: `ms`, `s`, `min`. Cannot be expressed with any other construct. See [US-1.15](us-1-15-delayed-transitions.md).

---

## Reactive transitions (sub-machine or region enters a state)

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

`::` separates machine/region path from state name. `.` navigates within a machine's own hierarchy.  
`::final` and `P::done` are sugar — equivalent to explicitly listing each final state.  
See [US-1.13](us-1-13-machine-composition.md), [US-1.12](us-1-12-parallel-regions.md), [US-1.17](us-1-17-compound-reactive-conditions.md).

---

## Composition side effect

| Construct | Trigger | Scope | Effect |
|-----------|---------|-------|--------|
| `State -> event -> Dest => Mach.init` | Caller | Specific state | New state + spawns sub-machine |

The fork `=>` is an additional side effect on a regular transition, not a separate construct. See [US-1.13](us-1-13-machine-composition.md).

---

## Structural declarations (not transitions)

| Construct | Purpose |
|-----------|---------|
| `init(params) StateName` ─ | Typed construction-time inputs ([US-1.3](us-1-3-init-state-parameters.md)) |
| `final StateName(params)` ─ | Typed terminal output value ([US-1.5](us-1-5-final-state-output.md)) |
| `state Name @history` / `Name.History` ─ | Shallow history — restore last direct child on re-entry ([US-1.11](us-1-11-history-states.md)) |
| `state Name @history(deep)` ─ | Deep history — restore full active subtree on re-entry ([US-1.11](us-1-11-history-states.md)) |
| `@parallel Name` / `region R` ─ | Declare orthogonal regions ([US-1.12](us-1-12-parallel-regions.md)) |
| `@import Mach` / `@import Mach from Pkg` ─ | Declare sub-machine dependency ([US-1.13](us-1-13-machine-composition.md)) |

---

## Primitive vs. sugar summary

| Category | Primitive (unique semantic) | Sugar ◆ |
|----------|-----------------------------|---------|
| Caller-driven | `->`, `[guard]`, `-*>`, `/action` | `*` wildcard |
| Automatic | `always`, `@entry`, `@exit` | — |
| Timer | `after()` | — |
| Reactive | `@on ::State`, `@on X,S` | `::final`, `P::done`, `::*` |
| Composition | `=>` fork | — |

---

## The three orthogonal axes

| Axis | Values |
|------|--------|
| **Trigger** | Caller / Machine-internal (output event) / Entry-automatic / Timer / Reactive (`@on`) |
| **Scope** | Specific state / Any non-final (`*`) / Any parent (implicit in `@on`) / AND-scoped (`@on X, State`) |
| **Effect** | New state (`->`) / In-place no-lifecycle (`-*>` + action) / Output event stream (`-*>` no action) / Lifecycle side effect (`@entry`/`@exit`) / Fork (`=>`) |

**Key insight:** `-*>` has two distinct uses depending on whether an action is present: with action = in-place caller handler; without action = output event declaration. `*` is a scope modifier for caller-driven transitions only. `@on` is the entire reactive trigger domain.
