# Urkel DSL Showcase

A collection of `.urkel` state machine definitions covering every construct
in the Urkel DSL v2. Each example is self-contained and demonstrates specific
language features. The examples also serve as a stress-test of the DSL — known
gaps and design questions are documented inline with `# DSL GAP:` comments and
summarised at the bottom of this file.

> **Note:** These examples target the v2 DSL specification defined in
> [`../../userstories/`](../../userstories/README.md). Not all constructs are
> implemented in the current generator. See the build status of each example
> in the table below.

---

## Examples

| File | Machine | Key Features Demonstrated |
|------|---------|--------------------------|
| `toggle.urkel` | Toggle | Core structure, `*` wildcard, `final` |
| `traffic-light.urkel` | TrafficLight | `after()` timer, cyclic FSM |
| `door-lock.urkel` | DoorLock | Guards, event params, `after()`, `@entry`/`@exit` |
| `counter.urkel` | Counter | `-*>` handler, `-*>` output event, `@entry`, self-transition |
| `data-fetch.urkel` | DataFetch | Async loading pattern, timeout, `final` with output |
| `auth.urkel` | Auth | `after()` refresh timer, output event, guard on network |
| `folder-watch.urkel` | FolderWatch | `init` params, output events, producer lifecycle |
| `price-ticker.urkel` | PriceTicker | Multiple output events, reconnect loop |
| `media-player.urkel` | MediaPlayer | Compound states, `@history`, history target |
| `ble-peripheral.urkel` | BLEPeripheral | `init` params, reconnect with `after()`, output event |
| `ble-scale.urkel` | Scale | `@import`, `=>` fork, `@on` reactive, `@on X, OwnState` |
| `ble-heart-rate.urkel` | HeartRate | Composition + output events, compound `@on` condition |
| `elevator.urkel` | Elevator | Compound state, `@history`, `after()` auto-close |
| `checkout.urkel` | Checkout | Sequential wizard, guards, `final` with output, progress output |
| `vending-machine.urkel` | VendingMachine | Complementary guards on same event, coin accumulation |
| `print-job.urkel` | PrintJob | `@parallel`, `region`, `@on P::done`, `@on P.Region::State` |
| `ble-blender.urkel` | BLEBlender | Large flat FSM, `@import`, speed changes via `-*>` |
| `runner.urkel` | Runner | `@entry`/`@exit`, `always` + guard, `-*> always` per-frame |
| `enemy-ai.urkel` | EnemyAI | `after()` timers, `-*> always` per-frame, `always` guard |
| `game-session.urkel` | GameSession | Full UI flow, `@entry`/`@exit` for effects, output events |

---

## DSL Features Coverage

| Feature | Example(s) |
|---------|-----------|
| `init(params) State` | `folder-watch`, `price-ticker`, `ble-peripheral` |
| `state Name(params)` (state-carried data) | `data-fetch` GAP |
| `final Name(params)` | `data-fetch`, `checkout`, `vending-machine` |
| `state Name @history` | `media-player`, `elevator` |
| `@entry` / `@exit` | `door-lock`, `counter`, `folder-watch`, `runner`, `enemy-ai`, ... |
| `[guard]` | `door-lock`, `auth`, `checkout`, `ble-scale` |
| `-*>` in-place handler | `counter`, `folder-watch`, `media-player`, `runner`, `enemy-ai` |
| `-*>` output event | `counter`, `folder-watch`, `price-ticker`, `ble-peripheral`, ... |
| `always` (eventless) | `runner`, `enemy-ai` |
| `-*> always / action` | `runner`, `enemy-ai` |
| `after(duration)` | `traffic-light`, `door-lock`, `auth`, `elevator`, `enemy-ai`, ... |
| `*` wildcard source | `toggle`, `traffic-light`, `checkout`, `game-session` |
| Compound state `{ }` | `media-player`, `elevator` |
| `@parallel` / `region` | `print-job` |
| `@import` + `=>` fork | `ble-scale`, `ble-heart-rate`, `ble-blender` |
| `@on Mach::State` | `ble-scale`, `ble-heart-rate` |
| `@on X, OwnState` | `ble-scale`, `ble-heart-rate` |
| `@on P::done` | `print-job` |
| `@on P.Region::State` | `print-job` |
| Doc comments (`##`) | `folder-watch`, `ble-scale`, `ble-heart-rate`, `media-player` |

---

## Known DSL Gaps

These are design questions or limitations surfaced by writing the examples.

### GAP-1: State-carried data on non-final, non-init states

**Found in:** `data-fetch.urkel` (`state Loaded(data: Data)`)

The grammar supports params on `init` and `final` states, but not on regular
`state` declarations. When a non-terminal state needs to carry typed data (e.g.
loaded content, a measurement result), there is no clean DSL mechanism.

**Options:**
- Allow `state Name(params)` — cleanest; extend grammar for all state kinds.
- Use an output event: `Loading -*> loaded(data: Data)` — caller observes data,
  but the machine has no typed `Loaded` state that carries it.
- Store in context — removes the data from the DSL entirely.

**Recommendation:** Allow params on all `state` kinds (symmetric with `init`/`final`).

---

### GAP-2: Fork `=>` cannot pass construction params to sub-machines

**Found in:** `ble-scale.urkel`, `ble-heart-rate.urkel`

`=> BLEPeripheral.init` spawns the sub-machine but cannot pass its `init` params
(e.g. `serviceUUIDs: [String]`). The workaround is to have the parent's context
provide those values, but this is implicit and undeclared in the DSL.

**Options:**
- Allow `=> Sub.init(param: value)` syntax in the fork clause.
- Require that forked sub-machines have a no-param `init` state, and pass config
  through the context bundle instead.

**Recommendation:** Allow optional param list on fork: `=> Sub.init(serviceUUIDs: uuids)`.

---

### GAP-3: Complementary guards — no "else" or unmatched-event handler

**Found in:** `vending-machine.urkel`

Two transitions share the same source + event but have complementary guards:
```
AcceptingCoins -> selectItem(code: String) [hasSufficientFunds]  -> DispensingItem
AcceptingCoins -> selectItem(code: String) [insufficientFunds]   -> AcceptingCoins
```
If neither guard is true (or both are), the event is silently dropped (or
non-deterministic). There is no `[else]` fallback guard in the DSL.

**Options:**
- Add a special `[else]` guard that matches when no prior guard matched.
- Require the validator to check guard exhaustiveness (hard in general).
- Document as a convention: complementary guards are the author's responsibility.

**Recommendation:** Add `[else]` as a reserved guard name meaning "no other guard matched".

---

### GAP-4: Output events are not observable by parent machines via `@on`

**Found in:** `ble-heart-rate.urkel`, `game-session.urkel`

`@on` reacts to **state changes** in sub-machines. Output events (`-*>` without
action) are streams for the **API consumer** — they are not observable by parent
machines using `@on`. If a parent needs to react to child output, it must observe
a state change, not a stream value.

This is a fundamental architectural boundary: output events are API-level signals,
`@on` is machine-to-machine signalling. They intentionally serve different roles.

**Status:** By design. Document clearly in the language spec.

---

### GAP-5: `@entry`/`@exit` on compound state children require dot notation

**Found in:** `media-player.urkel`

`@entry Active.Playing / startPlayback` uses dot notation to target a nested
state. The v1 grammar only allows a plain `Identifier` as the state name in
`@entry`/`@exit`. The v2 grammar introduces `StateRef` (dot-qualified path) to
handle this, but it is new syntax that needs parser support.

**Status:** Addressed in v2 grammar (`StateRef ::= Identifier { "." Identifier }`).

---

### GAP-6: `always` + `-*>` for per-frame updates may be ambiguous with eventless transitions

**Found in:** `runner.urkel`, `enemy-ai.urkel`

Two uses of `always` on the same state:
```
Jumping -*> always           / applyGravityUp       # per-frame action, stays
Jumping -> always [upwardVelocityZero] -> Falling   # conditional state change
```
The first is an unconditional in-place per-frame hook; the second is a
conditional eventless transition. The distinction is clear (arrow type + guard),
but the order matters: the guarded state-change should be evaluated first, then
the in-place per-frame hook. The evaluation order of multiple `always` rules on
the same state needs to be specified.

**Recommendation:** State in the language spec: guarded `always ->` rules are
evaluated before unguarded `-*> always` per-frame hooks.
