# US-8.4: Templating Engine & BYOL (Bring Your Own Language) Guide

## 1. Objective
Document the Mustache templating pipeline so developers know how to write custom `.mustache` templates to generate Urkel state machines in Kotlin, TypeScript, or other foreign languages.

## 2. Context
Epic 7 unlocked massive power by allowing custom templates. However, to write a template, a developer needs to know exactly what variables are passed into the Mustache context. We must document the JSON/Dictionary structure of the exported `MachineAST`.

## 3. Acceptance Criteria
* **Given** a developer wants to write a `typescript.mustache` template.
* **When** they read the "Custom Templates" guide.
* **Then** they can see a clear JSON representation of the `MachineAST` context (e.g., how the `states` array and `transitions` arrays are formatted).
* **And Then** they are provided with a working example of a basic custom template.
* **And Then** the CLI usage (`--template` and `--ext`) is clearly demonstrated.

## 4. Implementation Details
* Create `Custom-Templates.md`.
* Document the exact dictionary keys exposed by the `MustacheExportEngine` (e.g., `{{machineName}}`, `{{#states}}`, `{{name}}`, `{{kind}}`).
* Provide a snippet of the bundled `kotlin.mustache` file as a reference implementation for complex structures like sealed interfaces.
