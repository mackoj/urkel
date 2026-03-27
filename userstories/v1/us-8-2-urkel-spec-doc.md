# US-8.2: The Urkel Language Specification Guide

## 1. Objective
Create a definitive, exhaustive DocC article detailing the `.urkel` file syntax, the EBNF grammar, and the BYOT (Bring Your Own Types) philosophy.

## 2. Context
Developers need a "dictionary" for the Urkel language. This guide will act as the source of truth for what can and cannot be written inside a `.urkel` file. It must explain the nuances of defining payloads, importing modules, and the strict requirement of exactly one `init` state.

## 3. Acceptance Criteria
* **Given** the Urkel DocC catalog.
* **When** a user reads the "Language Specification" article.
* **Then** they see a clear explanation of `@imports`, `@factory`, `@states`, and `@transitions`.
* **And Then** the article explains the BYOT concept, proving that users can use any valid Swift type (e.g., `Result<Data, Error>`) in their event payloads.
* **And Then** the formal `grammar.ebnf` is included and explained in simple terms.

## 4. Implementation Details
* Create an article `Language-Spec.md` in the DocC catalog.
* Use code blocks to show side-by-side comparisons of "Good" vs "Bad" syntax.
* Explicitly document the comment syntax (`//`).
* Explain the rules of the Validator (e.g., why dead-end transitions or missing initial states will fail compilation).
