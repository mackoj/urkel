# US-10.5: Template Model Expansion for Kotlin Quality Parity

## 1. Objective
Improve template-emitter output quality by expanding the template context model so Kotlin generation can approach Swift emitter ergonomics and correctness.

## 2. Context
Swift uses a dedicated emitter with richer decisions and documentation, while Kotlin uses Mustache templates over a flattened context. Bridging this gap requires a richer, structured template model rather than template complexity alone.

## 3. Acceptance Criteria
* **Given** bundled Kotlin template generation.
* **When** emitted.
* **Then** output includes clearer sections, better naming metadata, and sufficient context to avoid ad-hoc template hacks.

* **Given** custom template users.
* **When** they inspect documentation.
* **Then** they can discover and use new context keys with stable semantics.

* **Given** existing templates.
* **When** Urkel is upgraded.
* **Then** backwards compatibility is preserved or migration guidance is provided.

## 4. Implementation Details
* Extend `MachineAST.templateContext` with derived metadata:
  * normalized symbol names
  * grouped transitions
  * state role flags (initial/terminal)
  * reusable doc-friendly labels
* Keep existing keys available while adding versioned docs for new fields.
* Update bundled `kotlin.mustache` to leverage richer metadata.

## 5. Testing Strategy
* Snapshot tests for template context payload.
* Kotlin template output snapshots before/after with focused expectations.
* Compatibility tests for existing template keys.
