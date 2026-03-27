# US-4.5: Namespaced States & Typed Internal Context

## 1. Objective
Harden generated Swift output so multiple Urkel-generated machines can coexist in the same module without symbol collisions, while improving runtime safety by replacing opaque `Any` internal context with a machine-scoped typed context model.

## 2. Context
US-4.4 introduced runtime ergonomics (`[Machine]State`, forwarding helpers, dependency defaults), but generated state markers are currently top-level (`Idle`, `Running`, `Stopped`) and context is stored as `Any`. In real apps with multiple machines, top-level state names can collide and `Any` weakens compile-time guarantees. This story makes generated code safer and module-friendly without losing sidecar extensibility.

## 3. Acceptance Criteria
* **Given** two generated machines in one Swift module (e.g. FolderWatch and Bluetooth) that both define `Idle` and `Running`.
* **When** the project builds.
* **Then** there are no symbol redefinition conflicts caused by generated state marker types.

* **Given** generated observer transitions and wrappers.
* **When** code is emitted.
* **Then** all state marker types are machine-scoped (namespace or machine-prefixed symbols) and references are updated consistently.

* **Given** generated observer runtime context storage.
* **When** code is emitted.
* **Then** internal context uses a machine-scoped typed model (not raw `Any`) for generated transition flow.

* **Given** sidecar runtime extensions (live/test/mock) that need custom payloads.
* **When** sidecars integrate with generated observers.
* **Then** they can still hook into generated APIs through a stable extension point without editing generated files directly.

* **Given** existing Urkel examples and emitter snapshots.
* **When** tests run.
* **Then** updated generated output compiles and snapshots reflect namespaced types/context strategy.

## 4. Implementation Details
* Introduce machine-scoped state symbols using one of:
  * nested namespace (preferred): `enum [Machine]Machine { enum Idle {} ... }`, or
  * prefixed symbols: `[Machine]Idle`, `[Machine]Running`, etc.
* Update emitter-generated observer signatures, transition extensions, and wrapper enum cases to use namespaced state types.
* Replace direct `Any` storage with a typed machine-scoped context representation for generated transition plumbing.
* Preserve/extend sidecar integration hook (e.g. `withInternalContext`) so custom runtime files remain regeneration-safe.
* Ensure dependency client output remains unchanged in behavior (`testValue`, `previewValue`, `liveValue`) except for updated observer type references.
* Keep generated APIs source-stable where possible; document any intentional breaking changes.

## 5. Testing Strategy
* Add emitter tests that generate two machines with overlapping state names and assert output compiles together.
* Update inline snapshot tests for new namespaced type emission.
* Keep integration compile test (`generatedSwiftCompiles`) passing with the new context/state model.
* Add focused tests for sidecar hook compatibility (typed context access path still available).

## 6. Out of Scope
* New DSL syntax for explicit namespace declarations.
* Cross-file state sharing between different machines.
* Runtime reflection/dynamic dispatch over machine states.
