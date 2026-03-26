  XState features Urkel lacks

  🔴 Missing entirely

  ┌────────────────────────────────┬───────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────┐
  │ XState feature                 │ What it does                                          │ Urkel today                                                    │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Guards                         │ Conditional transitions — same event, different       │ Not in grammar or emitter. All transitions are unconditional.  │
  │                                │ target based on a predicate                           │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Entry / Exit actions           │ Side-effects fired on entering or leaving a state     │ No @entry / @exit concept                                      │
  │                                │ (logging, analytics, cleanup)                         │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Self-transitions / targetless  │ Handle an event without changing state (update        │ Every transition must have a source and a destination          │
  │ transitions                    │ context, fire a side-effect)                          │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Parallel states                │ Multiple independent regions active simultaneously    │ @compose is sequential lifecycle management; true concurrency  │
  │                                │                                                       │ between regions is absent                                      │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Hierarchical / parent states   │ Nested states; child inherits parent transitions      │ Flat state list only                                           │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ History pseudostates           │ Re-enter a parent state at the last active child      │ No hierarchy = no history                                      │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Delayed transitions (after)    │ Automatically transition after a timeout              │ No timer concept                                               │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ always / eventless transitions │ Transition immediately when guard passes, no event    │ Not supported                                                  │
  │                                │ needed                                                │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ invoke (services/actors)       │ Spawn a Promise, Observable, or child machine for the │ @compose covers lifecycle but not arbitrary async work /       │
  │                                │ lifetime of a state                                   │ observables                                                    │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ spawn                          │ Create a long-lived child actor dynamically at        │ No dynamic actor spawning                                      │
  │                                │ runtime                                               │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Context mutation (assign)      │ Update context data during transitions                │ @context sets a type, but there's no assign-style in-DSL       │
  │                                │                                                       │ update syntax                                                  │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ onDone / onError               │ React to a child machine or invoked service           │ No completion callbacks                                        │
  │                                │ completing                                            │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ Multiple transitions for same  │ An event can have an ordered list of guarded          │ Only one transition per event per source state                 │
  │ event                          │ alternatives                                          │                                                                │
  ├────────────────────────────────┼───────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────┤
  │ State inspection / devtools    │ @statelyai/inspect, Stately Studio visual editor      │ No runtime inspection API                                      │
  └────────────────────────────────┴───────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────┘

  🟡 Partially supported

  ┌──────────────────────────┬───────────────────────────────────────────────────┬──────────────────────────────────────────────────────────────────────────┐
  │ XState feature           │ What Urkel has                                    │ What's missing                                                           │
  ├──────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
  │ Child machine            │ @compose lifecycle bridge (start/stop/error       │ True bidirectional event passing; composed machine driving parent        │
  │ composition              │ forwarding)                                       │ transitions; onDone from child                                           │
  ├──────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
  │ Typed context            │ machine Foo<MyContext> threads a context type     │ No in-DSL way to express context mutations — consumers write those in    │
  │                          │ through transitions                               │ closures manually                                                        │
  ├──────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
  │ Non-escaping / move      │ ~Copyable machines enforce linear state           │ Only Swift; no equivalent for Kotlin template                            │
  │ semantics                │ consumption                                       │                                                                          │
  ├──────────────────────────┼───────────────────────────────────────────────────┼──────────────────────────────────────────────────────────────────────────┤
  │ Tooling                  │ VS Code LSP, watch mode, build-tool plugin,       │ No visual editor, no test utilities (model-based testing), no state      │
  │                          │ command plugin                                    │ inspector                                                                │
  └──────────────────────────┴───────────────────────────────────────────────────┴──────────────────────────────────────────────────────────────────────────┘

  🟢 Urkel advantages over XState

   - Type-safe state at compile time via ~Copyable + Sendable generics — impossible states are a compile error, not a runtime check
   - Swift concurrency native — async/await, actor-isolated sub-FSMs, sending-safe
   - Multi-language output (Swift, Kotlin, custom Mustache templates) from one .urkel source
   - No runtime — generates plain Swift structs; zero dependencies beyond what you choose to import
   - @continuation — non-consuming state accessor pattern with no XState equivalent

  ----------------------------------------------------------------------------------------------------------------------------------------------------------

  Additional details worth noting

  Validation the agent confirmed:

   - The validator checks for unreachable terminal states (cycle detection) — something XState relies on you to discover at runtime
   - @continuation return types are enforced by the validator — no silent failures

  Two hidden planned features in comments:

   - Fork operator (>>) — parallel sub-machine spawning, drafted but not in grammar yet
   - SwiftSyntax-based emitter (Epic 12) — replace string concatenation in SwiftCodeEmitter with SwiftSyntaxBuilder for safer generated code

  One nuance on @compose vs XState's invoke:
  XState's invoke can target a Promise, Observable, or another machine and listens for onDone/onError. Urkel's @compose is strictly lifecycle-forwarding
  (start/stop/error) with no event passing back up to the parent — the composed machine is fire-and-forget once started.

  Highest-value gaps to close (in priority order)

   1. Guards — most commonly needed, relatively small DSL/emitter change
   2. Entry/exit actions — declarative @entry/@exit hooks per state
   3. onDone from composed machines — let a composed machine's terminal state trigger a parent transition
   4. Delayed transitions — after(duration) -> TargetState using Swift's Task.sleep
   5. Parallel regions — true concurrent substates (biggest design effort)
