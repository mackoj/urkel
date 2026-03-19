# US-8.5: Step-by-Step Interactive DocC Tutorials

## 1. Objective
Utilize DocC's `@Tutorial` syntax to create an engaging, Apple-style interactive onboarding experience where users build a fully functional `FolderWatch` state machine from scratch.

## 2. Context
Articles are great for reference, but tutorials are how developers actually learn tools. By guiding the user through creating the `.urkel` file, generating the code, and wiring up the live business logic, we guarantee a frictionless "Aha!" moment.

## 3. Acceptance Criteria
* **Given** the DocC catalog.
* **When** navigating to the Tutorials section.
* **Then** there is a Table of Contents containing at least two chapters.
* **Given** Chapter 1: "Building Your First Machine".
* **When** the user follows the steps.
* **Then** they are guided through installing the SPM Plugin, writing `FolderWatch.urkel`, and observing the generated Swift code.
* **Given** Chapter 2: "Wiring the Business Logic".
* **When** the user follows the steps.
* **Then** they learn how to create the `_RunningState` actor and implement the `liveValue` dependency client to handle the actual side effects.

## 4. Implementation Details
* Create a `Tutorials/` folder inside the `.docc` catalog.
* Create a `TableOfContents.tutorial` file.
* Use `@Step` and `@Code` directives to show side-by-side progression of the `.urkel` file and the corresponding Swift implementation file.
* Include screenshots or code snippets of the Xcode build phases to show how the SPM plugin integrates seamlessly.
