# AccordMémo

Windows desktop business application for customer, piano, tuning and annual reminder management.

AccordMémo was developed for **Pianos d'Occitanie**, a professional piano tuning and maintenance business.

The application replaces manual customer follow-up with a structured local workflow:

**Customer → Piano → Tuning → Annual Reminder → Email → Follow-up**

The project is also an example of how I approach business software: understand the real operational problem first, model the domain, isolate external dependencies and keep the architecture proportional to the product.

---

## The problem

A piano tuning business needs to maintain long-term relationships with its customers.

A typical customer may require another tuning approximately one year after the previous intervention.

Managing those follow-ups manually becomes difficult as the customer base grows:

- Which customers need to be contacted today?
- Which piano was tuned?
- When was the last intervention?
- Has the customer already been reminded?
- Was the reminder postponed or cancelled?
- Has a new tuning reset the reminder lifecycle?
- What happened previously with this customer?

AccordMémo centralizes this information locally and turns it into an actionable workflow.

---

## Main features

### Customer management

- customer records
- contact information
- customer search
- customer details
- activity history

### Piano management

- multiple pianos per customer
- piano type and information
- tuning history
- piano-specific operations

### Tuning management

- record tuning interventions
- correct tuning information
- preserve historical data
- determine the latest tuning for a piano

### Annual reminders

- reminder lifecycle
- dashboard of reminders requiring attention
- postpone reminders
- cancel future reminders
- send reminder emails
- track reminder activity

### Gmail integration

Reminder emails can be sent through Gmail using Google OAuth.

Authentication and email delivery are isolated from the business logic through application ports.

### Backup

Local business data can be backed up and validated before restoration.

### Windows distribution

The application is designed specifically for Windows desktop use and includes installer preparation for deployment on the customer's workstation.

---

## Architecture

AccordMémo follows a pragmatic combination of:

- Domain-Driven Design
- Hexagonal Architecture
- SOLID principles

The goal is not to apply patterns for their own sake.

The architecture exists primarily to keep business rules independent from Flutter, SQLite, Gmail and Windows-specific infrastructure.

```text
┌─────────────────────────────────────┐
│            Presentation             │
│                                     │
│ Flutter UI • Riverpod • Dialogs     │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│             Application             │
│                                     │
│ Use cases • Services • Queries      │
│ Ports • Orchestration               │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│                Domain               │
│                                     │
│ Customer • Piano • Tuning           │
│ Reminder • Activity • CalendarDate  │
│ Repository contracts                │
└─────────────────────────────────────┘
                   ▲
                   │ implements ports
                   │
┌─────────────────────────────────────┐
│           Infrastructure            │
│                                     │
│ Drift / SQLite • Gmail • OAuth      │
│ Secure Storage • Filesystem • UUID  │
└─────────────────────────────────────┘
```

Dependency direction remains focused on the business core.

## Project structure

```text
lib/
├── application/
│   ├── backup/
│   ├── customer/
│   ├── dashboard/
│   ├── history/
│   ├── piano/
│   ├── ports/
│   ├── reminder/
│   └── tuning/
│
├── domain/
│   ├── activity/
│   ├── customer/
│   ├── piano/
│   ├── reminder/
│   ├── shared/
│   └── tuning/
│
├── infrastructure/
│   ├── email/
│   ├── files/
│   ├── google/
│   ├── ids/
│   ├── persistence/
│   ├── security/
│   └── time/
│
└── presentation/
    ├── clients/
    ├── dashboard/
    ├── history/
    ├── settings/
    ├── shell/
    └── theme/
```

## Domain model

The core model revolves around a few explicit business concepts:

```text
Customer
   │
   └── Piano
          │
          └── Tuning
                 │
                 └── Reminder
```

Activities provide an auditable history of relevant operations.

Business calendar dates are represented separately from technical timestamps through CalendarDate.

This avoids coupling business concepts such as a tuning date to unnecessary time-of-day or timezone semantics.

## Dependency boundaries

External dependencies are hidden behind explicit contracts where abstraction provides concrete value.

Examples:

```text
Clock
    └── SystemClock

IdGenerator
    └── UuidIdGenerator

EmailSender
    ├── GmailEmailSender
    └── FakeEmailSender

GoogleAuthSession
    ├── GoogleApisAuthSession
    └── FakeGoogleAuthSession

SecretStore
    └── FlutterSecureSecretStore

CustomerRepository
    └── DriftCustomerRepository

PianoRepository
    └── DriftPianoRepository

ReminderRepository
    └── DriftReminderRepository

TuningRepository
    └── DriftTuningRepository
```

These boundaries make the core behavior testable without requiring Gmail, Google authentication, Windows secure storage or a production database.

## Persistence

AccordMémo uses:

SQLite + Drift

The database stores:

customers
pianos
tunings
reminders
activities

Persistence models are mapped explicitly to domain models.

Database schema evolution is handled through migrations.

Because AccordMémo stores real business data locally, migrations are treated as production behavior rather than implementation details.

Dedicated migration tests verify upgrade paths for the different tables.

## Testing strategy

Testing is performed across the architecture rather than only at UI level.

```text
test/
├── application/
├── domain/
├── infrastructure/
├── presentation/
└── support/
```

### Domain tests

Business entities and value objects are tested independently.

Examples:

Customer
Piano
Tuning
Reminder
Activity
CalendarDate

### Application tests

Use cases and application services are tested against controlled dependencies.

Examples include:

recording a tuning
correcting a tuning
reminder lifecycle
sending reminders
dashboard classification
backup behavior

### Infrastructure tests

Infrastructure behavior is also tested, including:

Drift repositories
database behavior
database migrations
SQLite backup validation
Gmail message generation
Google authentication integration boundaries

### Presentation tests

Selected pages, dialogs and error mappings are tested at presentation level.

### Test doubles

Deterministic test infrastructure includes:

FixedClock
FakeIdGenerator
FakeFileLocationPicker
InMemoryCustomerRepository
InMemoryPianoRepository
InMemoryReminderRepository
InMemoryTuningRepository
InMemoryActivityRepository
InMemorySecretStore

This keeps core tests independent from external services and system time.

## Security

The application interacts with Google OAuth and Gmail, so credentials are treated as infrastructure concerns rather than application state.

Principles used in the project include:

no credentials committed to source control
no OAuth tokens stored directly in source code
secure storage for sensitive local credentials
external authentication isolated behind application ports
explicit error handling around external services
minimal coupling between business logic and authentication infrastructure

## Technology

### Application

Flutter
Dart
Riverpod

### Persistence

SQLite
Drift

### External integration

Google OAuth
Gmail API

### Security

Flutter Secure Storage

### Tooling

Git
Flutter Test
Drift code generation
Windows installer tooling

## Development history

The repository was built incrementally around the business domain rather than generated as a finished code dump.

The main progression was:

```text
Windows project initialization
        ↓
Local persistence foundation
        ↓
Customer domain
        ↓
Piano domain
        ↓
Tuning domain
        ↓
Reminder lifecycle
        ↓
Activity history
        ↓
Desktop UI
        ↓
Customer & piano workflows
        ↓
Gmail OAuth integration
        ↓
Windows installer
```

This progression is visible in the Git history.

## Engineering principles

A few principles guide the project:

Understand the business problem before writing code.

Keep the domain independent from frameworks.

Abstract external dependencies when the boundary has concrete value.

Do not create abstractions for hypothetical future requirements.

Make time, IDs and external services controllable in tests.

Treat database migrations as production features.

Prefer simple explicit code over unnecessary sophistication.

## Status

AccordMémo is under active development for its intended Windows desktop environment.

Current work focuses on completing the operational reminder workflow, Gmail integration, backup behavior and production distribution.

## About this repository

AccordMémo is both a real business application and a demonstration of my approach to software engineering.

I focus on turning operational requirements into maintainable software while keeping technical decisions tied to actual business needs.

The architecture is intentionally explicit, but it is not the objective of the project.

The objective is to solve the user's problem reliably.
