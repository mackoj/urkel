# US-4.4: Runtime Scaffolding & Ergonomics

## 1. Objective
Enhance the Swift emitter so generated machines are not only type-safe at compile time, but also ergonomic to use at runtime. This is achieved by emitting practical scaffolding such as a combined state wrapper (`[MachineName]State`), state-unwrapping accessors, and dependency defaults.

## 2. Context
Current Urkel output proves typestate transitions, but it is still fairly low-level compared to the original `FolderWatch` reference. App developers often need a single mutable handle that can represent any lifecycle phase. Additionally, because the Urkel EBNF strictly defines *transitions* but not *properties* (like an `events` stream), we need a safe way for developers to access specific states at runtime. This story closes the ergonomic gap by generating a unified wrapper and dependency placeholders, while strictly preserving the boundaries of the DSL.

## 3. Acceptance Criteria
* **Given** a generated machine with states `Idle`, `Running`, `Stopped`.
* **When** code is emitted.
* **Then** it includes a generated enum wrapper `public enum [MachineName]State: ~Copyable` with cases for each concrete observer state.

* **Given** a developer stores the machine state in one variable (`let state: FolderWatchState`).
* **When** they call generated convenience methods (`start`, `stop`, etc.) on the wrapper.
* **Then** valid transitions are forwarded to the underlying typestate, and invalid transitions are **explicitly handled as a no-op** by returning the same wrapper state unchanged (without throwing an error).

* **Given** a developer needs to access properties specific to a single state (e.g., an `events` stream on the `Running` state).
* **When** using the generated wrapper.
* **Then** they can use a generated borrowing helper (e.g., `state.withRunning { $0.events }`) that executes only when that state is active and returns `nil` otherwise.

* **Given** generated dependency client code.
* **When** emitted.
* **Then** it includes default dependency scaffolding (`testValue`, `previewValue`, and a configurable placeholder `liveValue` policy) suitable for Point-Free Dependencies workflows.

* **Given** generated type names.
* **When** emitting observer and client symbols.
* **Then** names are normalized to Swift PascalCase conventions (e.g., `FolderWatchObserver`).

## 4. Implementation Details
* In `UrkelEmitter`, add two new phases for ergonomic runtime scaffolding:
  * `emitCombinedStateWrapper(for ast: MachineAST)`
  * `emitDependencyDefaults(for ast: MachineAST)`
* **The Wrapper:** Generate `public enum [MachineName]State: ~Copyable` with one case per state defined in the AST.
* **Forwarding (No-Op Policy):** Generate consuming transition methods on the wrapper (`consuming func event(...) async throws -> Self`). These methods must `switch consume self`. For valid states, execute the transition and return the next wrapper case. For invalid states, explicitly return the unchanged wrapper case as a safe no-op.
* **State Access:** For every state, generate a borrowing helper on the wrapper:
   ```swift
   public borrowing func with[StateName]<R>(
       _ body: (borrowing [MachineName]Observer<[StateName]>) throws -> R
   ) rethrows -> R? {
       switch self {
       case let .[stateName](observer):
           return try body(observer)
       case ...:
           return nil
       }
   }
   ```
* **Dependency Defaults:** Emit `extension [MachineName]Client: DependencyKey`. Populate `testValue`, `previewValue`, and `liveValue` with safe `fatalError()` placeholders.

## 5. Testing Strategy
*(Test Checklist Table Pending)*

## 6. Out of Scope
* **Domain Property Generation:** The Emitter will *not* attempt to generate domain-specific properties (like event streams or CoreBluetooth peripherals). It only generates the unwrapping accessors, leaving the property implementation to the developer via custom extensions.
