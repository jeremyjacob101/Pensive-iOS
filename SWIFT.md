# SWIFT.md

## Native iOS Migration Manual (SwiftUI + Convex)

Version: 1.0  
Project: Pensive  
Date: 2026-05-26  
Status: Implementation Contract  
Target: iOS 17+  
Backend: Convex (existing schema/functions remain source-of-truth)  
Integration Mode: HTTP wrapper layer from iOS  
Delivery Mode: Balanced (feature parity + native polish per module)

---

## How To Use This Document

This is a sequential execution manual for Codex in a fresh workspace.
This file is the single source-of-truth for migration execution.

Run in strict order:
1. Part 1
2. Part 2
3. Part 3
4. Part 4
5. Part 5
6. Part 6
7. Part 7
8. Part 8
9. Part 9
10. Part 10
11. Part 11
12. Part 12

Rule: Do not skip parts. Later parts assume artifacts from earlier parts.

Each part includes:
- Objective
- Inputs required
- Outputs to produce
- Detailed implementation tasks
- Acceptance criteria
- Tests
- Common failure modes

---

## Bootstrap Checklist (Copied From Prior README)

Use this section as the startup guardrail in a new workspace.

### Locked Targets
- Platform: iOS (mobile)
- Minimum deployment target: iOS 17.0
- UI framework: SwiftUI
- Backend: Convex (existing schema/functions are source-of-truth)
- Integration style: HTTP wrapper layer from iOS to Convex endpoints
- Migration execution: this `SWIFT.md`, sequentially Part 1 -> Part 12

### Required Inputs In Workspace
- `SWIFT.md` (this file)
- `.env` (real env values for local work)
- `.env.example` (sanitized template)
- `convex/` folder (current schema + functions)

### Execution Rules For Codex
1. Read this `SWIFT.md` before coding.
2. Execute one part at a time, strictly in order.
3. After each part, provide:
   - artifacts created/updated
   - acceptance criteria proof
   - tests run + results
   - open risks/blockers
4. Do not start the next part until current part is accepted.

### Build Command Expectations
Use these command expectations unless the workspace explicitly changes them.

1. Install dependencies:
```bash
npm install
```

2. Convex codegen/dev sync (when backend changes or generated types are needed):
```bash
npx convex dev
```

3. iOS build (CLI expectation):
```bash
xcodebuild -scheme Pensive -destination 'platform=iOS Simulator,name=iPhone 17' build
```

4. iOS test (CLI expectation):
```bash
xcodebuild -scheme Pensive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PensiveTests test
xcodebuild -scheme Pensive -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PensiveUITests/PensiveUITests/testLaunchShowsRootView test
```

Notes:
- For simulator stability and reproducibility, follow `SIMULATOR.md` exactly for every iOS build/test run.
- If the scheme/device name differs, update commands accordingly.
- If the project uses an `.xcworkspace`, use `-workspace` plus `-scheme`.
- Keep build/test commands reproducible for CI.
- Run unit and UI test commands sequentially (not in parallel) to avoid simulator test-runner collisions.
- Do not use `Any iOS Simulator Device` for tests; use a concrete simulator destination.

### Prompt Templates For New Codex Window
Kickoff prompt:
`Read SWIFT.md and execute Part 1 only. Create all required artifacts, then show acceptance-criteria proof and tests run before moving to Part 2.`

Part 3 opener:
`Start Part 3. Generate API_CONTRACT.md first from current convex/ functions and schema, complete it fully, then implement the iOS HTTP wrapper against that contract.`

---

## No-Gaps Audit Checklist (Required After Every Part)

This checklist is mandatory after each part (Parts 1 through 12).  
Do not proceed to the next part until every checklist item below is answered explicitly.

### A. Scope Lock
- Confirm: “Only Part X was implemented in this cycle.”
- List any out-of-scope changes that were made anyway (if any), with justification.

### B. Artifact Completeness
- List every file created/updated/deleted.
- For each changed file, state why it changed and which part requirement it satisfies.
- Confirm required outputs for the part were produced exactly as specified.

### C. Acceptance Proof
- Paste a point-by-point checklist of this part’s acceptance criteria.
- Mark each item `pass` / `fail`.
- For each `pass`, include concrete proof (test output summary, screenshot description, file reference, or behavior evidence).
- For each `fail`, include impact and remediation plan.

### D. Test Evidence
- List all tests run for this part (unit/integration/UI/manual as relevant).
- Include command(s) executed.
- Include result summary (`passed`, `failed`, `skipped` counts).
- If tests were not run, explain exactly why and list risk introduced.

### E. Parity Gap Disclosure (Mandatory)
- List every known parity gap between source web behavior and current iOS state, even if minor.
- For each gap include:
  - severity (`critical`, `high`, `medium`, `low`)
  - affected feature
  - user-visible impact
  - planned part for resolution
- Explicitly state: “No known parity gaps” only if truly none exist.

### F. API/Contract Integrity (When Applicable)
- Confirm whether API contracts changed this cycle.
- If yes, update `API_CONTRACT.md` and list exact sections changed.
- Confirm iOS implementation remains consistent with contract examples.

### G. Risk + Next-Step Readiness
- List top 3 technical risks remaining after this part.
- State whether the project is ready to proceed to Part X+1 (`yes` / `no`).
- If `no`, list required fixes before continuing.

### H. Sign-Off Block (Required)
Use this exact footer after each part report:

`Part X Sign-Off:`  
`- Scope gate: pass/fail`  
`- Acceptance gate: pass/fail`  
`- Test gate: pass/fail`  
`- Parity gap gate: pass/fail`  
`- Ready for next part: yes/no`

---

## Repository Reality Snapshot (Source App)

Current source app routes/pages to preserve functionally:
- `/login`
- `/expenses`
- `/incomings`
- `/breakdown`
- `/recurrings`
- `/tracking`
- `/notepad`
- `/options`

Current Convex domain modules to preserve:
- `auth`
- `expenses`
- `incomings`
- `recurrings`
- `summaries`
- `tracking`
- `userOptions`
- `notepad`
- `paybackLinks`
- `monthYears` helpers

Core data behaviors to preserve:
- Auth-gated per-user data
- Expense/incoming CRUD with date + monthYears interplay
- Grouped partner entries (`base*Id`, `sub*Id`)
- Effective amount logic (`auto` / `manual`)
- Payback allocation links between expenses and incomings
- Recurring definitions and materialization behavior
- Breakdown scoped analytics and charts
- Tracking timelines with start month + trailing buffer
- Notepad notes + editable table workspace
- User option taxonomies with subtype movement/promotion/rename and tracking flags

---

# Part 1: Product Parity Contract + Architecture

## Mandatory Part Gate (Before Moving On)
- Do Part 1 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Lock exact parity goals and architecture before coding.

## Inputs Required
- This `SWIFT.md`
- Current React + Convex repo behavior

## Outputs
- `docs/ios/parity-matrix.md`
- `docs/ios/architecture.md`
- `docs/ios/ux-mapping.md`

## Detailed Tasks

### 1.1 Create parity matrix
Define every feature row with:
- Source location (page/component/module)
- Behavior summary
- iOS target behavior
- Status (`not-started`, `in-progress`, `done`, `verified`)

Minimum matrix sections:
- Auth
- Navigation shell
- Expenses
- Incomings
- Recurrings
- Breakdown
- Tracking
- Notepad
- Options
- Global search/filter/scope controls
- Error/loading/empty states

### 1.2 Lock web-to-iOS UX mapping
Decisions:
- Left menu rail -> `TabView` bottom tabs
- Dense row layouts -> card stacks with expandable details
- Right-docked actions -> toolbar/sheet actions
- Hover interactions -> explicit tap controls
- Drag interactions -> long-press + context actions/sheets

### 1.3 Lock architecture layers
Use this package/module structure:
- `App/` (entrypoint, composition root)
- `Presentation/` (SwiftUI views, view models)
- `Domain/` (entities, use-cases, business rules)
- `Data/` (repositories, DTO mappers)
- `Networking/` (HTTP client, auth transport, retry)
- `Infrastructure/` (logging, persistence helpers)
- `Resources/` (assets, localizations)

### 1.4 Cross-cutting standards
Define standards for:
- Currency: ILS formatting with deterministic rounding
- Dates: ISO `yyyy-MM-dd` storage/transport, locale-formatted display
- Month key: `yyyy-MM`
- Optimistic UI: only where safe; otherwise server-authoritative update
- Offline mode: read cached snapshot, queue nothing by default (phase 1)
- Accessibility baseline: Dynamic Type, VoiceOver labels, hit areas >=44pt
- Localization readiness: all user strings extractable

## Acceptance Criteria
- Every source feature has a parity target row.
- Architecture and UX mapping docs are complete and non-conflicting.
- No unresolved “TBD” on high-impact flows.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Manual review checklist on parity matrix completeness.

## Failure Modes
- Missing parity item discovered late in build.
- Architecture drift across features.

---

# Part 2: iOS Project Bootstrap + Environment

## Mandatory Part Gate (Before Moving On)
- Do Part 2 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Stand up a production-structured SwiftUI app foundation and config system.

## Inputs Required
- Apple Developer account/project conventions
- Convex deployment metadata
- Environment values (provided separately)

## Outputs
- Xcode project (SwiftUI lifecycle)
- Build configurations: `Debug`, `Staging`, `Release`
- `.xcconfig` hierarchy
- Runtime config loader
- DI bootstrap and root shell

## Detailed Tasks

### 2.1 Create project scaffold
- App name: `Pensive`
- Min deployment: iOS 17.0
- Language: Swift
- UI: SwiftUI
- Tests: unit + UI test targets

### 2.2 Build configuration strategy
Files:
- `Config/Base.xcconfig`
- `Config/Debug.xcconfig`
- `Config/Staging.xcconfig`
- `Config/Release.xcconfig`

Keys to include:
- `CONVEX_BASE_URL`
- `CONVEX_HTTP_ACTION_BASE_URL` (if separate)
- `AUTH_CLIENT_ID` (if required by wrapper)
- `APP_ENV_NAME`
- `LOG_LEVEL`

### 2.3 Runtime environment injection
- Read config via `Bundle.main.object(forInfoDictionaryKey:)`
- Validate at launch and fail-fast in debug when missing
- Provide `AppEnvironment` struct to DI container

### 2.4 Dependencies (SPM only)
Include:
- `swift-collections` (if needed)
- `swift-log` (optional)
- `Swift Charts` (Apple framework, no package)
- No unnecessary dependencies for v1 parity

### 2.5 Root app shell
Create:
- `PensiveApp.swift`
- `AppContainer` for dependency graph
- `RootView` handling auth gate state routing

## Acceptance Criteria
- App boots to deterministic root shell in all 3 configurations.
- Env missing -> descriptive debug failure.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Unit test: config parser reads each expected key.
- Smoke UI test: app launch + root view visible.
- Execute these tests with concrete simulator destination and sequential order:
  1) `xcodebuild ... -only-testing:PensiveTests test`
  2) `xcodebuild ... -only-testing:PensiveUITests/PensiveUITests/testLaunchShowsRootView test`

## Failure Modes
- Secrets accidentally committed.
- Env mismatches between build configs.

---

# Part 3: Convex HTTP Integration Layer

## Mandatory Part Gate (Before Moving On)
- Do Part 3 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Define and implement the canonical typed HTTP wrapper for all Convex interactions from iOS.

## Inputs Required
- Existing Convex functions and schema
- Backend HTTP strategy (wrapper endpoints available)

## Outputs
- `Networking/HTTPClient.swift`
- `Networking/ConvexTransport.swift`
- `Data/API/ConvexAPI.swift` and module-specific APIs
- `API_CONTRACT.md` (generated first from current `convex/` source-of-truth)
- Endpoint contract docs
- DTO + mapper set

## Detailed Tasks

### 3.0 Hard gate: generate contract before implementation
Before writing iOS networking code, generate `API_CONTRACT.md` from current `convex/` functions and schema.

This is mandatory for this migration. Do not implement wrapper code before this file exists and is reviewed.

`API_CONTRACT.md` must include, at minimum:
- Contract version/date and source commit hash.
- Auth transport contract (headers/cookies/token semantics).
- Standard response envelope and error envelope.
- Endpoint index grouped by domain:
  - auth
  - expenses
  - incomings
  - recurrings
  - summaries
  - tracking
  - notepad
  - userOptions
  - paybackLinks
- For every endpoint:
  - path
  - method
  - required auth
  - request schema (required/optional fields)
  - response schema
  - error codes/messages
  - idempotency notes (if any)
  - one concrete example request/response
- Validation/normalization rules:
  - date formats (`YYYY-MM-DD`)
  - month key format (`YYYY-MM`)
  - numeric precision rules for money/effective amounts
  - typed ID conventions
- Recurring-specific notes for current schema:
  - canonical `amount` field (not `price`)
  - `kind`-scoped field families (`recurringExpense*` / `recurringIncoming*`)
  - materialization contract with `runDate` and idempotency key shape
  - explicit disallow of legacy recurring payload keys from iOS clients

Gate acceptance criteria for 3.0:
- `API_CONTRACT.md` exists in repo root.
- Every required Convex capability from Part 3.2 is represented.
- No unresolved `TBD` in request/response schemas.
- Recurring contract reflects current backend behavior exactly.

### 3.1 API surface contract
Define protocol grouping:
- `AuthAPI`
- `ExpensesAPI`
- `IncomingsAPI`
- `RecurringsAPI`
- `SummariesAPI`
- `TrackingAPI`
- `NotepadAPI`
- `UserOptionsAPI`
- `PaybackLinksAPI`

Also umbrella:
- `protocol ConvexAPI { var auth: AuthAPI { get } ... }`

### 3.2 Endpoint catalog from source behavior
Minimum required capabilities:
- Expenses:
  - listByDateScope, monthBounds, create, update, remove
  - bulkCreate, bulkPatchVisible
  - renameBaseExpense, removeBaseExpense
  - addPartnerExpense, unlinkExpenseFromPartners
- Incomings:
  - same shape as expenses where applicable
- Recurrings:
  - list, create, update, remove, setStatus, materializeDueExpenses
  - cleanupRecurringKindFields (maintenance/admin path)
  - migrateLegacyRecurringsForUserIds (internal migration path)
- Summaries:
  - range
- Tracking:
  - list
- Notepad:
  - getMine, note/table mutate operations
- UserOptions:
  - list/add/updateColor/remove/setDefault/setTracking/rename/move/promote
- PaybackLinks:
  - listForExpense/listForIncoming/list candidates/create/update/remove
- Auth:
  - sign-in, sign-out, session check

### 3.3 DTO design and normalization
Create network DTOs separate from domain models.
Normalization rules:
- Date strings normalized to strict ISO on ingress.
- Month keys validated with `^\d{4}-(0[1-9]|1[0-2])$`.
- IDs represented as typed wrappers (`DocumentID<T>` style).
- Optional fields mapped explicitly; avoid silent defaults except documented.

### 3.4 Error mapping
Define typed errors:
- `networkUnavailable`
- `unauthorized`
- `forbidden`
- `notFound`
- `validation(message)`
- `server(message)`
- `decoding(message)`

### 3.5 Retry/timeout policy
Defaults:
- Timeout: 20s queries, 30s mutations
- Retry: idempotent reads only, max 2 retries with jitter backoff
- Never retry non-idempotent mutations automatically

### 3.6 Observability hooks
- Request/response timing
- Endpoint name and status code
- Correlation ID support if backend returns one
- Redact PII in logs

## Acceptance Criteria
- Every required feature endpoint has typed request/response.
- Error states are deterministic and test-covered.
- Wrapper implementation is traceable endpoint-by-endpoint to `API_CONTRACT.md`.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Contract completeness test:
  - Cross-check `API_CONTRACT.md` endpoint index against exported Convex capabilities used by iOS.
- Mapper tests:
  - Ensure DTO/domain conversion matches examples in `API_CONTRACT.md`.
- Contract tests for encode/decode per endpoint.
- Mock transport tests for status/error mapping.

## Failure Modes
- Building wrapper directly from assumptions without first writing/locking `API_CONTRACT.md`.
- Date normalization mismatch causing scope bugs.
- ID typing drift causing wrong endpoint payloads.

---

# Part 4: Auth + Session Lifecycle

## Mandatory Part Gate (Before Moving On)
- Do Part 4 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Rebuild protected/public route behavior with native app auth state machine.

## Inputs Required
- Auth endpoints/transport from Part 3

## Outputs
- `Domain/Auth/AuthState.swift`
- `Presentation/Auth/AuthViewModel.swift`
- Login UI and root gate handling

## Detailed Tasks

### 4.1 Auth state machine
States:
- `launching`
- `loadingSession`
- `unauthenticated`
- `authenticating`
- `authenticated(UserSession)`
- `authError(AuthError)`

Transitions must be explicit and testable.

### 4.2 Session bootstrap
On launch:
- Attempt session restore/check
- Move to authenticated or unauthenticated root

### 4.3 Sign-in flow
- Email normalized `trim + lowercase`
- Password required
- Loading/disabled button UX
- Inline, human-readable errors

### 4.4 Sign-out flow
- Clear in-memory caches tied to user
- Clear auth tokens
- Return to unauthenticated root

### 4.5 Token expiry handling
- On 401 from protected endpoint:
  - attempt refresh/revalidation if supported
  - otherwise force sign-out with message

## Acceptance Criteria
- Root gating behavior matches web protected/public intent.
- Session persistence works across relaunch.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- State machine transition tests.
- Integration tests for launch -> auth routing.

## Failure Modes
- Ghost authenticated UI after token invalidation.
- Race condition between launch load and initial screen rendering.

---

# Part 5: App Navigation + Global UI Shell

## Mandatory Part Gate (Before Moving On)
- Do Part 5 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Implement native mobile shell that preserves functionality with iOS-first structure.

## Inputs Required
- Auth state from Part 4
- Feature stubs for tabs

## Outputs
- Bottom-tab `TabView`
- Global quick-add launcher
- Shared search/filter/scope scaffolding

## Detailed Tasks

### 5.1 Tab architecture
Tabs:
- Expenses
- Incomings
- Breakdown
- Recurrings
- Tracking
- Notepad
- Options

Implementation note: if 7 tabs feel crowded, use 5 visible + “More” pattern or grouped navigation while keeping direct access acceptable.

### 5.2 Navigation stacks
Each tab gets independent `NavigationStack` and restoration-friendly path state.

### 5.3 Global quick-add
Replace top add panel with:
- Toolbar plus button opening sheet
- Sheet supports creating expense/incoming/recurring
- Keep validation and option creation helpers

### 5.4 Shared control primitives
Build reusable components:
- Search bar with debounce
- Multi-select filter chips/sheets
- Month navigator control
- Date range picker sheet
- Loading/empty/error state views

### 5.5 Theme strategy
Default to system light/dark; no custom theme toggle required for parity v1.

## Acceptance Criteria
- User can reach all feature areas quickly on mobile.
- Shell handles deep links and state restoration baseline.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- UI tests for tab switching + quick-add sheet launch.

## Failure Modes
- Navigation path resets unexpectedly when switching tabs.

---

# Part 6: Expenses + Incomings (Core Ledger)

## Mandatory Part Gate (Before Moving On)
- Do Part 6 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Ship full ledger parity with native card-based interaction.

## Inputs Required
- APIs from Part 3
- Shared shell controls from Part 5

## Outputs
- Expenses and Incomings modules with CRUD + filters + scope + partner/group features

## Detailed Tasks

### 6.1 Domain models
Define:
- `Expense`, `Incoming`
- `EffectiveAmountMode`
- Grouping metadata (`baseExpenseId`, `subExpenseId`, etc.)
- Scope matching status (`full`, `monthYearsOnly`, `dateOnly`)

### 6.2 List + scope behavior
Implement:
- `monthBounds`
- Date/month scope query
- Month overlap disclaimers exactly preserved:
  - “applied this month/s, paid in different month”
  - “paid this month, applied to different month/s”

### 6.3 Filters/search
Parity requirements:
- account/category filters (expense)
- account/type filters (incoming)
- multi-field text search
- persisted filter selections locally per tab

### 6.4 CRUD + editing
- Card rows with compact summary + expandable details
- Edit in modal sheet with form validation
- Delete confirmation required
- Bulk create support path preserved

### 6.5 Partner/group operations
Expenses:
- add partner
- unlink partner
- rename/remove base group
Incomings:
- add/unlink partner

### 6.6 Effective amounts + payback integration
- Show raw and effective amounts
- Manual/auto mode support
- Launch payback link manager from row details

### 6.7 Option handling
- In-form “add missing option” flow
- Resolve colors via options mapping

## Acceptance Criteria
- Ledger flows functionally match source behavior.
- Search + filters + date scope interplay is correct.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Unit tests for filtering and scope match state.
- Integration tests for CRUD + partner operations.
- Snapshot/UI tests for expanded/editing states.

## Failure Modes
- Scope mismatch due to monthYears/date logic drift.
- Grouped amount display inconsistencies.

---

# Part 7: Recurrings + Materialization Behavior

## Mandatory Part Gate (Before Moving On)
- Do Part 7 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Deliver complete recurring management for both expense and incoming kinds.

## Inputs Required
- Recurrings API from Part 3
- Options APIs and models

## Outputs
- Recurrings screen with dual sections and edit flows

## Detailed Tasks

### 7.1 List and segmentation
- Fetch paginated recurring list
- Split by kind: expense vs incoming
- Active/inactive visual state
- Treat `kind` as optional in persisted legacy rows and default display to `expense` when missing until migration cleanup is complete.

### 7.2 CRUD and status
- Create recurring (kind-specific required fields)
- Edit recurring in modal form
- Toggle active/inactive with loading lock
- Delete recurring with confirmation
- Use canonical recurring payload fields (current schema):
  - `status`
  - `kind`
  - `name`
  - `amount` (not `price`)
  - `frequency`
  - `dayOfMonth`
  - `recurringExpense*` or `recurringIncoming*` family (kind-dependent)
  - `notes`

### 7.3 Validation matrix
Expense kind required:
- recurringExpenseType
- recurringExpenseAccount
- recurringExpenseCategory
- recurringExpensePaidTo
Incoming kind required:
- recurringIncomingPaidBy
- recurringIncomingType
- recurringIncomingAccount

Kind cleanup rule (must mirror backend behavior):
- If `kind == expense`, all `recurringIncoming*` fields must be cleared (`undefined`/omitted in updates).
- If `kind == incoming`, all `recurringExpense*` fields must be cleared.

### 7.4 Materialization behavior
- Wire explicit action for due materialization endpoint
- Show result summary (created count/errors)
- Prevent duplicate trigger spam with in-flight lock
- Materialization contract must match backend:
  - Input: `runDate` as `YYYY-MM-DD`
  - Due selection by `dayOfMonth`
  - Idempotency via `automationKey = recurring:{kind}:{recurringId}:{runDate}`
  - Creates expense/incoming rows with `amount` copied from recurring
  - Sets generated rows `effectiveAmountMode = auto`, `effectiveAmount = amount`
  - Uses recurring kind-specific fields (`recurringExpense*` or `recurringIncoming*`)

### 7.5 Legacy migration + hygiene
- Include a one-time migration utility in iOS rollout runbook to coordinate backend maintenance calls:
  - `cleanupRecurringKindFields`
  - internal migration path for legacy recurring rows (`migrateLegacyRecurringsForUserIds`)
- Explicitly disallow iOS clients from sending legacy recurring keys (`price`, `type`, `paidBy`, `category`, `paidTo`, `expenseType`, `incomingType`, etc.).

## Acceptance Criteria
- Recurring behaviors and fields match backend expectations.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Validation tests by recurring kind.
- Status toggle and materialization integration tests.

## Failure Modes
- Incorrect field fallback causing backend validation errors.

---

# Part 8: Breakdown + Summaries + Charts

## Mandatory Part Gate (Before Moving On)
- Do Part 8 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Recreate analytics surfaces with native charts and precise scoped totals.

## Inputs Required
- Summaries + scoped lists
- User option color metadata

## Outputs
- Breakdown screen with filters, totals, monthly buckets, and charts

## Detailed Tasks

### 8.1 Scope + filtering
- Support month mode and custom range mode
- Filters:
  - expense account/type/category
  - incoming account/type
- Persist deselections locally

### 8.2 Totals and buckets
Display both:
- Raw totals
- Effective totals
For:
- Expenses
- Incomings
- Net
And monthly buckets list/table equivalent.

### 8.3 Chart implementation
Use Swift Charts for:
- Range/category pie-like breakdown equivalents
- Monthly trend visuals
- Accessible labels and legend mapping to option colors

### 8.4 UX polish
- Fast filter toggles
- Smooth skeleton/loading transitions
- Drill-down from chart segment to filtered list where practical

## Acceptance Criteria
- Numbers reconcile with backend scoped summaries.
- Filter and scope changes update visuals correctly.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Unit tests for aggregate computations in mappers/view models.
- Snapshot tests across key filter states.

## Failure Modes
- Effective/raw column swaps.
- Color mismatch for subtype labels.

---

# Part 9: Tracking Timeline Experience

## Mandatory Part Gate (Before Moving On)
- Do Part 9 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Rebuild tracking rows with horizontal month timeline and persisted per-row state.

## Inputs Required
- Tracking API rows
- Local persistence service

## Outputs
- Tracking screen with expense/incoming grouped timeline cards

## Detailed Tasks

### 9.1 Data model
For each row preserve:
- key
- source (`expense`/`incoming`)
- label
- color
- paidMonths
- currentMonth

### 9.2 Local state parity
Persist per row:
- start month selection
- trailing buffer months

Storage keys should map to iOS equivalents; migration from old local storage not required unless webview hybrid exists.

### 9.3 Timeline rendering
- Horizontal scroll segments
- states: paid, unpaid, trailing buffer, empty filler
- snap toward newest month on first render

### 9.4 Interaction
- Start month dropdown/picker per row
- Buffer stepper/selector per row
- VoiceOver descriptions for each segment status and month

## Acceptance Criteria
- Paid/buffer logic matches source semantics.
- Persisted settings restore correctly after app relaunch.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Unit tests for month range generation and segment status logic.
- UI tests for state persistence and row interaction.

## Failure Modes
- Off-by-one month range errors.
- Scroll snapping interfering with manual navigation.

---

# Part 10: Notepad Workspace (Notes + Tables)

## Mandatory Part Gate (Before Moving On)
- Do Part 10 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Recreate notepad hybrid workspace (notes + editable tables) with autosave.

## Inputs Required
- Notepad API module

## Outputs
- Notes panel
- Tables panel with row/column editing
- Debounced save engine

## Detailed Tasks

### 10.1 Workspace loading
- Load `getMine`
- Normalize notes/tables client-side to robust defaults

### 10.2 Notes UX
- Create note
- Rename note (debounced save)
- Edit content (debounced autosave)
- Remove empty notes via cleanup strategy if required

### 10.3 Tables UX
- Add table
- Rename/delete table
- Edit individual cells
- Add/remove row
- Add/remove column

### 10.4 Performance and input handling
- Virtualization not required initially unless large datasets observed
- Optimize cell focus transitions and keyboard avoidance
- Prevent save stampede via keyed debounce timers

### 10.5 Error recovery
- Inline non-blocking save errors
- Retry on next edit event

## Acceptance Criteria
- Typical notes/tables workflows are smooth and reliable.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Unit tests for table normalization and local edit reducers.
- Integration tests for debounced save semantics.

## Failure Modes
- Lost edits due to race between local state and server patch.

---

# Part 11: Options System + Taxonomy Management

## Mandatory Part Gate (Before Moving On)
- Do Part 11 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Deliver full taxonomy management parity with mobile-native interaction replacements for drag-drop.

## Inputs Required
- UserOptions API

## Outputs
- Options screen with CRUD, color, defaults, tracking, move/promotion flows

## Detailed Tasks

### 11.1 CRUD parity
Kinds:
- expenseType
- account
- category
- subcategory
- incomeType
- incomeSubtype

Operations:
- add
- rename
- delete
- recolor
- set default
- set tracking

### 11.2 Replace drag/drop with mobile-native flows
Use explicit actions:
- “Move to subtype” sheet
- “Move subtype under parent” sheet
- “Promote subtype to parent” action

### 11.3 Integrity rules
- Prevent invalid move cycles
- Validate parent compatibility by kind
- Confirm destructive mutations
- Ensure downstream UI updates in ledger screens

### 11.4 Color behavior parity
- Preserve/update color normalization
- Ensure high contrast for badge visibility

## Acceptance Criteria
- All option transformations execute successfully via backend contracts.

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Unit tests for move/promotion request builders.
- Integration tests for mutation flows and UI refresh propagation.

## Failure Modes
- Orphaned subtype relationships after rename/move edge cases.

---

# Part 12: Quality Gates, Hardening, and Ship Checklist

## Mandatory Part Gate (Before Moving On)
- Do Part 12 only.
- Show acceptance criteria proof.
- Show tests run and results.
- List any parity gaps explicitly before moving on.
- Complete the No-Gaps Audit Checklist (see section: `No-Gaps Audit Checklist (Required After Every Part)`) before requesting the next part.

## Objective
Harden for release-quality iOS experience and verify parity completion.

## Inputs Required
- Completed Parts 1-11

## Outputs
- Final QA matrix
- Release checklist
- TestFlight candidate readiness artifacts

## Detailed Tasks

### 12.1 Final parity audit
- Revisit `parity-matrix.md`
- Every row marked `verified`
- Any deliberate non-parity documented with rationale

### 12.2 Automated testing coverage
Required suites:
- Unit: domain logic, mappers, state machines
- Integration: API client contracts with mocked transport
- UI tests: critical user journeys per tab

### 12.3 Manual acceptance scripts
Create runbook:
- Auth lifecycle
- Full expense/incoming CRUD and filtering
- Recurring + materialization
- Breakdown totals/charts sanity
- Tracking timeline interactions
- Notepad autosave reliability
- Options move/promotion integrity

### 12.4 Performance checklist
- Launch time acceptable on baseline device
- Scrolling smoothness for long lists
- No obvious memory growth from repeated navigation
- Network batching where useful, avoid chatty duplicate calls

### 12.5 Accessibility + native polish
- VoiceOver labels/traits complete
- Dynamic Type large sizes usable
- Color contrast and touch targets compliant
- Haptics on key state changes where appropriate

### 12.6 Release readiness
- Crash logging hooks integrated
- Analytics event taxonomy documented
- TestFlight release notes template
- Rollback plan and feature flag defaults (if used)

## Acceptance Criteria
- All critical flows pass automated + manual checks.
- Build is testflight-ready with documented known issues (if any).

## Tests
- Simulator execution: follow `SIMULATOR.md` exactly for destination, derived data path, sequential runs, and recovery steps.
- Full regression suite pass.

## Failure Modes
- Last-minute regressions from late polish edits.

---

## Canonical Public Interfaces / Types To Define

Implement these as first-class contracts:

### API Protocols
- `ConvexAPI`
- `AuthAPI`
- `ExpensesAPI`
- `IncomingsAPI`
- `RecurringsAPI`
- `SummariesAPI`
- `TrackingAPI`
- `NotepadAPI`
- `UserOptionsAPI`
- `PaybackLinksAPI`

### Shared Primitives
- `MonthYear` (validated wrapper)
- `DateScope` (`singleMonth` | `customRange`)
- `MoneyAmount`
- `EffectiveAmountMode` (`auto` | `manual`)
- `OptionKind`
- `AuthState`

### Domain Entities
- `Expense`
- `Incoming`
- `Recurring`
- `UserOption`
- `TrackingRow`
- `NotepadWorkspace`
- `PaybackLink`

### ViewModel Contracts
Each tab view model should expose:
- `state` (`loading` | `empty` | `data` | `error`)
- read-only view data
- intent methods (`onAppear`, `refresh`, `create`, `update`, etc.)
- controlled side effects (navigation events, toasts/alerts)

---

## Convex HTTP Wrapper Contract Guidance

Because iOS is using HTTP wrapper integration:
- Backend should expose stable HTTP actions/endpoints that proxy existing Convex queries/mutations.
- Endpoint naming should be feature-scoped and versioned when possible, e.g. `/v1/expenses/listByDateScope`.
- Use JSON body for all mutations and scoped queries.
- Include a standard envelope for success/error:

```json
{
  "ok": true,
  "data": { }
}
```

```json
{
  "ok": false,
  "error": {
    "code": "validation",
    "message": "..."
  }
}
```

- Document auth header contract (`Authorization: Bearer <token>` or session cookie strategy).
- Never leak internal stack traces to client.

---

## Definition Of Done (Whole Migration)

The migration is done when all are true:
1. All parity matrix rows are `verified`.
2. iOS app supports complete day-to-day workflow without web fallback.
3. Convex-backed data correctness matches source behavior.
4. Automated tests for critical flows pass in CI.
5. Accessibility and performance baseline checks pass.
6. Release checklist is complete and testflight build is distributable.

---

## Execution Commands For Future Codex Session

When you move this into a new workspace, run this cadence:
1. “Start Part 1 from SWIFT.md. Create all specified docs and artifacts.”
2. “Start Part 2 from SWIFT.md …”
3. Continue through Part 12.
4. After each part: require acceptance criteria proof + tests run summary.

Required discipline:
- No skipping forward.
- No architecture rewrites without updating Part 1 docs.
- Keep parity matrix current in every PR/iteration.

---

## Assumptions and Defaults Locked

- Backend Convex schema/functions remain source-of-truth.
- iOS consumes backend via HTTP wrapper layer.
- System light/dark mode used by default.
- Mobile-native interaction redesign is allowed when preserving functional parity.
- Exact environment values will be injected when provided in the new workspace.
