# US-9.5: Domain Boundaries

## 1. Objective
Keep Urkel generic by drawing a clear boundary between reusable FSM infrastructure and package-specific behavior such as platform APIs, event mapping, and fallback strategies.

## 2. Context
The FolderWatch package makes it clear that Urkel should generate the state-machine skeleton, but not assume anything about file watching, FSEvents, mocks, or noop implementations. Those concerns belong to the package that is using Urkel.

## 3. Acceptance Criteria
* **Given** a package uses Urkel for a machine.
* **When** it defines live, mock, preview, or noop strategies.
* **Then** those strategies remain package-owned and do not require Urkel to know the domain.

* **Given** a domain-specific event source.
* **When** the package integrates it with the generated FSM.
* **Then** the mapping layer stays outside the Urkel core.

* **Given** the Urkel docs and examples.
* **When** a new maintainer reads them.
* **Then** the reusable pieces and the app-specific pieces are clearly separated.

## 4. Implementation Details
* Document the intended extension points so users know what to implement themselves.
* Keep generated APIs focused on transitions, typing, and client wiring rather than domain behavior.
* Avoid introducing package-specific assumptions into generic runtime templates.

## 5. Testing Strategy
* Add docs or examples that show a custom domain integration next to the generated scaffold.
* Add a regression test that proves the core generator does not require a domain-specific implementation.

## 6. Follow-up Scope Extension
Validate the boundary with a second concrete package (BluetoothBlender) generated from Urkel output and sidecars, documenting what becomes generic and what remains intentionally domain-owned.
