# US-8.6: Generated File Integration & Sidecar Architecture Guide

## 1. Objective
Document a canonical, regeneration-safe integration pattern for Urkel-generated files so teams can wire runtime logic without editing generated code and without breaking when regeneration occurs.

## 2. Context
Urkel intentionally separates generated typestate interfaces from runtime/business logic. In practice, teams often need guidance on where to place custom code (`live`, `mock`, runtime actors, computed helpers), how to survive regeneration, and how to migrate when generated APIs evolve (such as namespaced states and typed context).

## 3. Acceptance Criteria
* **Given** a developer using Urkel in a Swift package.
* **When** they read the integration guide.
* **Then** they understand that `*+Generated.swift` is generated-only and must never be manually edited.

* **Given** custom runtime behavior is needed.
* **When** they follow the guide.
* **Then** they place business logic in sidecar files (for example `MachineClient+Runtime.swift`, `MachineClient+Live.swift`, `MachineClient+Test.swift`) that are safe across regeneration.

* **Given** a machine uses typed context (explicit `machine Name<ContextType>` or generated fallback).
* **When** they integrate runtime internals.
* **Then** they know how to model context transitions between states without `Any`-based casting.

* **Given** code generation is rerun.
* **When** the build and tests execute.
* **Then** sidecar integration remains source-compatible or migration points are clearly identified.

## 4. Implementation Details
* Create a DocC article (for example `Generated-File-Integration.md`) under the Urkel documentation catalog.
* Include a recommended folder layout:
  * `Machine.urkel` (source of truth)
  * `machine+Generated.swift` (generated, read-only)
  * sidecars for runtime/live/test helpers
* Document namespace-aware usage in sidecars:
  * refer to states as `MachineMachine.Idle/Running/Stopped` (or current generator naming)
  * avoid top-level state symbol assumptions
* Document typed context strategy:
  * prefer explicit machine context type in DSL for advanced runtime internals
  * if relying on generated fallback context, explain how to keep sidecar API aligned with generated shape
* Add a migration checklist section for regeneration-impact changes:
  * regenerate file
  * fix compile errors in sidecars first
  * run package tests

## 5. Testing Strategy
* Add documentation smoke checks if available in repo workflow.
* Validate examples in guide against a real integration sample (FolderWatch-style sidecars).
* Ensure no recommendation requires editing generated files directly.
