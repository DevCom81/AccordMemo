# AGENTS.md

## Project

AccordMémo is a Windows desktop business application developed for Pianos d'Occitanie.

Its purpose is to manage:

- customers
- pianos
- tuning history
- annual reminders
- reminder emails
- activity history
- local data backup and restore

The application is built with Flutter for Windows and uses a local SQLite database through Drift.

The project follows Domain-Driven Design principles, hexagonal architecture and SOLID principles where they provide concrete value.

Architecture must remain proportional to the actual complexity of the application.

---

## 1. Role of the AI agent

The AI agent is a technical challenger and implementation assistant.

It is not the technical lead and does not make architectural or product decisions autonomously.

The agent must:

- analyze the requested change before proposing code
- identify ambiguities, missing information and potential risks
- ask questions whenever an assumption would otherwise be necessary
- challenge questionable technical decisions
- propose alternatives when relevant
- explain advantages, drawbacks and consequences of each meaningful option
- prefer the simplest solution that correctly solves the problem
- respect existing architecture and conventions
- produce an implementation plan before modifying code
- wait for explicit approval before starting implementation

The agent must never assume undocumented business rules.

When information is missing, ask.

When uncertain, say so.

When several valid solutions exist, present them before choosing one.

---

## 2. Development workflow

For every non-trivial change:

1. Understand the business problem.
2. Inspect the relevant existing code.
3. Identify affected layers and dependencies.
4. Identify missing information or ambiguities.
5. Ask the necessary questions.
6. Propose one or more solutions when appropriate.
7. Explain risks and trade-offs.
8. Produce a concise implementation plan.
9. Wait for explicit approval.
10. Implement only the approved solution.
11. Propose the commands required to validate the implementation.

Do not start modifying code before approval.

Small mechanical corrections may be treated differently only when explicitly requested.

---

## 3. Human-controlled command execution

Commands affecting the development environment remain under human control.

The agent must not execute build, test, dependency, migration or deployment commands unless explicitly authorized.

Examples include:

```text
flutter test
flutter analyze
flutter run
flutter build
dart test
dart run build_runner
dart fix
dart format
```

## 4. Architecture

The application follows four main layers:

presentation
    |
    v
application
    |
    v
domain

infrastructure -> implements ports required by domain/application

Current structure:

lib/
├── application/
├── domain/
├── infrastructure/
├── presentation/
├── main.dart
└── main_demo.dart

Dependencies must point toward the business core.

The domain must not depend on Flutter, Drift, SQLite, Gmail, Google APIs, Windows APIs or any other infrastructure concern.

## 5. Domain layer

lib/domain/

The domain contains business concepts and business rules.

Examples:

Customer
Piano
Tuning
Reminder
Activity
CalendarDate

The domain may contain:

entities
value objects
domain rules
repository contracts
domain-specific types

The domain must remain framework-independent.

Do not import:

Flutter
Drift
SQLite
Gmail APIs
Google APIs
Windows-specific libraries
presentation code
infrastructure implementations

Business invariants belong here when they are intrinsic to the domain.

Invalid domain states should be prevented whenever reasonably possible.

## 6. Application layer

lib/application/

The application layer coordinates use cases.

Examples include:

customer management
piano management
recording a tuning
correcting a tuning
reminder lifecycle
sending reminder emails
dashboard queries
backup orchestration

Application code may depend on domain abstractions and application ports.

External systems must be accessed through explicit ports when abstraction provides real value.

Current examples include:

EmailSender
GoogleAuthSession
IdGenerator
SecretStore
TransactionRunner

Use cases should describe business intentions rather than technical operations.

Prefer names such as:

RecordTuning
SendReminder
CorrectTuning

over implementation-oriented names.

Do not move business rules into the presentation layer.

## 7. Infrastructure layer

lib/infrastructure/

Infrastructure contains technical implementations of contracts required by the core application.

Examples include:

Drift repositories
SQLite database
Gmail email sender
Google OAuth
UUID generation
secure credential storage
filesystem backup
system clock

Infrastructure may depend on external frameworks and libraries.

Infrastructure must not define business rules.

Mapping between persistence models and domain models must remain explicit.

Do not allow Drift-generated objects or external API models to leak into the domain.

## 8. Presentation layer

lib/presentation/

Presentation contains Flutter UI and presentation-specific state.

It may contain:

pages
dialogs
widgets
providers
formatters
UI strings
presentation error mapping
navigation

Presentation should call application use cases or services.

It must not directly implement business rules.

Avoid direct persistence or external API access from widgets.

Widgets should remain focused on display and user interaction.

## 9. Ports and abstractions

Do not create abstractions automatically.

An interface must have a concrete reason to exist.

Good reasons include:

isolating an external dependency
enabling deterministic tests
replacing infrastructure implementations
protecting the domain from framework dependencies
representing a meaningful architectural boundary

Current examples:

Clock -> SystemClock
IdGenerator -> UuidIdGenerator
EmailSender -> GmailEmailSender
SecretStore -> FlutterSecureSecretStore
Repository -> DriftRepository

Do not create interfaces merely because an implementation exists.

Avoid speculative abstractions.

Avoid architecture for architecture's sake.

## 10. SOLID

Apply SOLID pragmatically.

Single Responsibility

Classes should have a clear reason to change.

Open/Closed

Prefer extension through existing boundaries when appropriate, but do not introduce unnecessary abstraction for hypothetical future requirements.

Liskov Substitution

Implementations must respect the behavioral contract of their abstractions.

Interface Segregation

Prefer focused ports over large generic interfaces.

Dependency Inversion

Business code depends on abstractions at meaningful external boundaries.

Infrastructure provides implementations.

## 11. Persistence

The application uses Drift with SQLite.

Persistence rules:

persistence models must not become domain models
mapping must remain explicit
schema changes require migrations
existing user data must be preserved
migration behavior must be tested
database changes must consider upgrade paths from existing installations

Never assume that deleting and recreating the database is acceptable.

AccordMémo is a business application containing real customer data.

Data integrity has priority over implementation convenience.

## 12. Dates and time

Business calendar dates and technical timestamps are different concepts.

Use CalendarDate for business dates when time and timezone are irrelevant.

Use UTC timestamps for technical metadata where appropriate.

Time-dependent business logic must be testable.

Use the domain Clock abstraction rather than reading system time directly inside business logic.

Avoid hidden dependencies on DateTime.now().

## 13. Testing

Tests are part of the design, not an afterthought.

The project contains tests at several levels:

test/domain/
test/application/
test/infrastructure/
test/presentation/
test/support/

When changing behavior:

identify existing tests affected by the change
update them when the expected behavior legitimately changes
add tests for new business rules
add regression tests for bugs when appropriate
test failure cases, not only successful paths
preserve deterministic behavior

Use fakes and in-memory implementations where they improve isolation.

Current examples include:

FixedClock
FakeIdGenerator
InMemoryCustomerRepository
InMemoryPianoRepository
InMemoryReminderRepository
InMemoryTuningRepository
InMemorySecretStore

Database migrations must be tested.

External integrations should be isolated from core business tests.

The agent proposes validation commands. The developer decides when they are executed.

## 14. Security

Security must be considered during design, not added after implementation.

Never commit:

passwords
API keys
OAuth secrets
access tokens
refresh tokens
private credentials

Secrets must not be hard-coded in source files.

OAuth tokens and sensitive credentials must use appropriate secure storage.

Follow least-privilege principles for external permissions.

Validate external input at appropriate boundaries.

Do not log sensitive information.

Do not expose implementation details or credentials through user-facing errors.

When adding an external dependency or API integration, consider:

permissions
credential storage
token lifecycle
error handling
offline behavior
data exposure
failure recovery
## 15. Error handling

Errors should be handled at the layer where they can be meaningfully interpreted.

Infrastructure errors should not leak directly into the UI.

Application code should translate technical failures into meaningful application failures when appropriate.

Presentation code is responsible for converting application failures into understandable user messages.

Do not silently swallow errors.

Do not expose raw exceptions to end users.

## 16. Generated code

Generated files must not be manually edited.

Example:

app_database.g.dart

Modify the source definition and regenerate the file using the appropriate command.

The agent must propose the generation command rather than executing it unless explicitly authorized.

## 17. Code quality

Prefer:

explicit code
small focused classes
meaningful names
immutable state where practical
deterministic behavior
clear dependency boundaries
simple control flow

Avoid:

premature generalization
unnecessary inheritance
generic "manager" classes
giant services
hidden side effects
duplicated business rules
framework dependencies inside the domain
abstractions without a concrete purpose

Comments should explain why something exists when the reason is not obvious.

Do not comment code merely to restate what it does.

## 18. Refactoring

Do not mix large unrelated refactors with feature development.

When significant technical debt is discovered:

Identify it.
Explain its impact.
Determine whether it blocks the requested change.
Propose a separate refactoring when appropriate.

Do not rewrite working architecture simply because another approach is possible.

## 19. Decision making

When challenging an existing decision, structure the discussion around:

Problem
Current approach
Risk or limitation
Possible alternatives
Advantages
Drawbacks
Recommendation

A recommendation is not a decision.

Final architectural and product decisions remain with the human developer.

## 20. Git and change discipline

Changes should remain focused and reviewable.

Do not mix unrelated concerns in the same implementation when they can reasonably be separated.

Before proposing a commit:

identify the actual scope of the change
verify that unrelated files were not modified
identify generated files separately
identify configuration or dependency changes explicitly
summarize architectural consequences when relevant

Commit messages should describe intent rather than implementation noise.

Prefer conventional, meaningful messages such as:

feat: add reminder lifecycle
fix: prevent duplicate reminder scheduling
test: cover tuning correction failure cases
refactor: isolate Gmail authentication
build: prepare Windows installer

Avoid messages such as:

update
changes
fix stuff
final
working
test2

Do not rewrite published Git history merely to make it appear cleaner.

An authentic incremental history is preferable to an artificially reconstructed one.

## 21. Dependencies

Do not add a dependency automatically because it solves a small implementation problem.

Before introducing a package:

Explain why it is needed.
Check whether the existing stack already solves the problem.
Consider maintenance and platform implications.
Consider security implications.
Consider whether a small local implementation would be simpler.
Ask for approval.

Dependencies must serve the application, not replace basic engineering judgment.

## 22. Business-first development

A technically correct feature can still be a failed feature.

Before considering a feature complete, verify:

does it solve the original business problem?
is the workflow understandable for the actual user?
are failure states handled?
can existing data survive the change?
is the behavior testable?
does the solution introduce unnecessary complexity?
are external dependencies justified?

Do not optimize solely for technical elegance.

AccordMémo is used by a real business.

User workflow and data reliability are first-class engineering concerns.

## 23. Definition of done

A change is not complete merely because the code compiles.

Depending on the scope, completion should consider:

business behavior implemented
domain invariants preserved
architecture boundaries respected
relevant tests added or updated
failure paths considered
persistence migrations handled when required
sensitive information protected
user-facing errors understandable
generated code updated when required
validation commands identified
documentation updated when the behavior or architecture materially changes

The agent must clearly state anything that remains unverified.

Never claim that a build, test or deployment succeeded unless its result has actually been observed.

## 24. Core principle

AccordMémo exists to solve a business problem.

Architecture, frameworks and patterns are tools.

The objective is not to produce the most sophisticated codebase possible.

The objective is to produce software that is:

correct
understandable
maintainable
testable
secure
reliable
proportionate to the problem

Understand the problem first.

Then choose the solution.
