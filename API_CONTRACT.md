# API_CONTRACT.md

- Contract version/date: 2026-05-26
- Source commit hash: `62c55680353f37df0f52b80f2ade229c6efef0fa`
- Source of truth: `convex/schema.ts` + `convex/*.ts`

## Auth Transport Contract
- Protected endpoints require authenticated Convex user session.
- iOS sends `Authorization: Bearer <token>` when token exists.
- Session-cookie transport is also allowed when backend auth route uses cookies.
- Missing auth maps to `Unauthenticated` backend error.

## Standard Response Envelope
Success:
```json
{"ok":true,"data":{},"correlationId":"optional"}
```
Error:
```json
{"ok":false,"error":{"code":"validation","message":"..."},"correlationId":"optional"}
```

## Error Mapping Contract
- `401` / `code=unauthorized` -> unauthorized
- `403` / `code=forbidden` -> forbidden
- `404` / `code=not_found` or backend "Not found" -> notFound
- `422` / `code=validation` -> validation(message)
- `5xx` or unknown code -> server(message)
- invalid envelope payload -> decoding(message)

## Validation And Normalization
- Date input canonical storage: `YYYY-MM-DD`.
- Month key format: `YYYY-MM` (`^\d{4}-(0[1-9]|1[0-2])$`).
- Money fields are `number` (no client rounding before send).
- Convex document IDs are opaque strings and treated as typed IDs in iOS wrappers.

## Recurrings Special Contract
- Canonical recurring amount field: `amount`.
- Required kind-scoped fields:
  - `kind=expense`: `recurringExpenseType`, `recurringExpenseAccount`, `recurringExpenseCategory`, `recurringExpensePaidTo`
  - `kind=incoming`: `recurringIncomingPaidBy`, `recurringIncomingType`, `recurringIncomingAccount`
- Kind cleanup rule:
  - expense rows clear all `recurringIncoming*`
  - incoming rows clear all `recurringExpense*`
- Materialization:
  - input `runDate` (`YYYY-MM-DD`)
  - day match by `dayOfMonth`
  - idempotency key `recurring:{kind}:{recurringId}:{runDate}`
  - generated rows copy recurring `amount` into `amount` and `effectiveAmount`, with `effectiveAmountMode=auto`
- iOS must never send legacy recurring keys (`price`, `type`, `paidBy`, `category`, `paidTo`, `expenseType`, `incomingType`, ...).

---

## Endpoint Catalog And Schemas

### auth

1. `POST /api/auth/sign-in`
- auth: no
- request: `{email:string,password:string}`
- response: `{authenticated:boolean,userId?:string}`
- errors: validation/server
- idempotency: no
- example req: `{"email":"a@b.com","password":"secret"}`
- example res: `{"ok":true,"data":{"authenticated":true,"userId":"u1"}}`

2. `POST /api/auth/sign-out`
- auth: yes
- request: `{}`
- response: `{}`
- errors: unauthorized/server
- idempotency: no
- example req: `{}`
- example res: `{"ok":true,"data":{}}`

3. `GET /api/auth/session`
- auth: optional
- request: none
- response: `{authenticated:boolean,userId?:string}`
- errors: server
- idempotency: yes
- example res: `{"ok":true,"data":{"authenticated":false}}`

### expenses

1. `POST /api/expenses/list-by-date-scope`
- request: `{startDate,endDate,targetMonths?:string[],includeMonthYearOverlapOutsideDate?:boolean}`
- response: `Expense[]`
- errors: unauthorized/validation
- idempotency: yes
- example req: `{"startDate":"2026-05-01","endDate":"2026-05-31","targetMonths":["2026-05"],"includeMonthYearOverlapOutsideDate":true}`
- example res: `{"ok":true,"data":[{"_id":"e1","expense":"Rent","amount":1000,"monthYears":["2026-05"],"date":"2026-05-01","expenseId":"exp1"}]}`

2. `GET /api/expenses/month-bounds`
- response: `{newestMonth?:string,oldestMonth?:string}`
- idempotency: yes
- example res: `{"ok":true,"data":{"newestMonth":"2026-05","oldestMonth":"2024-01"}}`

3. `POST /api/expenses/create`
- request: `ExpenseMutationDTO`
- response: `string` (doc id)
- idempotency: no
- example req: `{"expense":"Rent","type":"Fixed","account":"Bank","category":"Home","amount":1000,"date":"2026-05-01","paidTo":"Landlord","expenseId":"exp_abc"}`
- example res: `{"ok":true,"data":"jd7..."}`

4. `POST /api/expenses/update`
- request: `ExpenseUpdateDTO`
- response: `string`
- idempotency: no
- example req: `{"id":"jd7...","expense":"Rent","type":"Fixed","account":"Bank","category":"Home","amount":1000,"date":"2026-05-01","paidTo":"Landlord","expenseId":"exp_abc"}`
- example res: `{"ok":true,"data":"jd7..."}`

5. `POST /api/expenses/remove`
- request: `{id:string}`
- response: `string`
- idempotency: no
- example req: `{"id":"jd7..."}`
- example res: `{"ok":true,"data":"jd7..."}`

6. `POST /api/expenses/bulk-create`
- request: `{rows:ExpenseMutationDTO[]}`
- response: `{inserted:number}`
- idempotency: no
- example res: `{"ok":true,"data":{"inserted":2}}`

7. `POST /api/expenses/bulk-patch-visible`
- request: `{ids:string[],patch:{type?,account?,category?,subcategory?,paidTo?,notes?,comments?}}`
- response: `{updatedCount:number}`
- idempotency: no
- example res: `{"ok":true,"data":{"updatedCount":3}}`

8. `POST /api/expenses/rename-base-expense`
- request: `{baseExpenseId:string,baseExpenseLabel:string}`
- response: `{updated:number}`
- example res: `{"ok":true,"data":{"updated":4}}`

9. `POST /api/expenses/remove-base-expense`
- request: `{baseExpenseId:string}`
- response: `{deleted:number,baseExpenseId:string}`
- example res: `{"ok":true,"data":{"deleted":2,"baseExpenseId":"expGroup1"}}`

10. `POST /api/expenses/add-partner-expense`
- request: `{anchorExpenseId:string,partnerExpenseId:string}`
- response: `{linked:number,baseExpenseId:string}`
- example res: `{"ok":true,"data":{"linked":2,"baseExpenseId":"expBase"}}`

11. `POST /api/expenses/unlink-expense-from-partners`
- request: `{expenseId:string}`
- response: `{unlinked:number,remainingLinked:number}`
- example res: `{"ok":true,"data":{"unlinked":1,"remainingLinked":1}}`

### incomings
Same shape as expenses equivalents with incoming fields.

1. `POST /api/incomings/list-by-date-scope` (read)
2. `GET /api/incomings/month-bounds` (read)
3. `POST /api/incomings/create`
4. `POST /api/incomings/update`
5. `POST /api/incomings/remove`
6. `POST /api/incomings/bulk-create`
7. `POST /api/incomings/bulk-patch-visible`
8. `POST /api/incomings/add-partner-incoming`
9. `POST /api/incomings/unlink-incoming-from-partners`

Example create req:
```json
{"incoming":"Salary","paidBy":"Employer","incomeType":"Job","account":"Bank","amount":5000,"date":"2026-05-01","incomingId":"inc_abc"}
```
Example create res:
```json
{"ok":true,"data":"incDocId"}
```

### recurrings

1. `POST /api/recurrings/list`
- request: `{paginationOpts:{cursor?:string,numItems:number}}`
- response: paginated recurring rows
- idempotency: yes

2. `POST /api/recurrings/create`
- request: `RecurringMutationDTO`
- response: `string`

3. `POST /api/recurrings/update`
- request: `RecurringUpdateDTO`
- response: `string`

4. `POST /api/recurrings/remove`
- request: `{id:string}`
- response: `string`

5. `POST /api/recurrings/set-status`
- request: `{id:string,status:"active"|"inactive"}`
- response: `string`

6. `POST /api/recurrings/materialize-due-expenses`
- request: `{runDate:string}`
- response: `{runDate,day,matched,created,skipped}`

7. `POST /api/recurrings/cleanup-recurring-kind-fields`
- request: `{}`
- response: `{updated:number}`

8. `POST /api/recurrings/migrate-legacy-recurrings-for-user-ids`
- request: `{userId:string,ids:string[]}`
- response: `{updated:number}`

Example materialize req/res:
```json
{"runDate":"2026-05-26"}
```
```json
{"ok":true,"data":{"runDate":"2026-05-26","day":26,"matched":4,"created":2,"skipped":2}}
```

### summaries

1. `POST /api/summaries/range`
- request: `{startDate:string,endDate:string}`
- response: `{startDate,endDate,totals,monthlyBuckets}`
- idempotency: yes
- example res: `{"ok":true,"data":{"startDate":"2026-05-01","endDate":"2026-05-31","totals":{"rawExpenses":10,"effectiveExpenses":10,"rawIncomings":20,"effectiveIncomings":20,"rawNet":10,"effectiveNet":10},"monthlyBuckets":[]}}`

### tracking

1. `GET /api/tracking/list`
- response: `{currentMonth:string,rows:TrackingRow[]}`
- idempotency: yes
- example res: `{"ok":true,"data":{"currentMonth":"2026-05","rows":[]}}`

### notepad

1. `GET /api/notepad/get-mine`
2. `POST /api/notepad/add-note`
3. `POST /api/notepad/cleanup-empty-notes`
4. `POST /api/notepad/rename-note`
5. `POST /api/notepad/save-note-content`
6. `POST /api/notepad/add-table`
7. `POST /api/notepad/rename-table`
8. `POST /api/notepad/delete-table`
9. `POST /api/notepad/save-cell`
10. `POST /api/notepad/add-row`
11. `POST /api/notepad/add-column`
12. `POST /api/notepad/remove-last-row`
13. `POST /api/notepad/remove-last-column`

Example save-cell req:
```json
{"tableId":"table-1","rowIndex":0,"colIndex":1,"value":"123"}
```
Example res:
```json
{"ok":true,"data":{}}
```

### userOptions

1. `GET /api/user-options/list`
2. `POST /api/user-options/add`
3. `POST /api/user-options/update-color`
4. `POST /api/user-options/remove`
5. `POST /api/user-options/set-default`
6. `POST /api/user-options/set-tracking`
7. `POST /api/user-options/rename`
8. `POST /api/user-options/move-to-subtype`
9. `POST /api/user-options/promote-subtype`
10. `POST /api/user-options/move-subtype`

Example update-color req:
```json
{"kind":"category","value":"Home","color":"#A1B2C3"}
```

### paybackLinks

1. `POST /api/payback-links/list-for-expense`
2. `POST /api/payback-links/list-for-incoming`
3. `GET /api/payback-links/list-incoming-candidates`
4. `GET /api/payback-links/list-expense-candidates`
5. `POST /api/payback-links/create`
6. `POST /api/payback-links/update`
7. `POST /api/payback-links/remove`

Example create req/res:
```json
{"expenseId":"expDoc","incomingId":"incDoc","allocatedAmount":120,"notes":"partial"}
```
```json
{"ok":true,"data":{"id":"pb1","warnings":[]}}
```

## Explicit Legacy Disallow List For iOS Recurring Payloads
- `price`
- `type`
- `paidBy`
- `category`
- `paidTo`
- `expenseType`
- `expenseAccount`
- `expenseCategory`
- `expenseSubcategory`
- `expensePaidTo`
- `incomingPaidBy`
- `incomingType`
- `incomingSubtype`
- `incomingAccount`

