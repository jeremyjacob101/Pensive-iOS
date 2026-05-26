import Foundation

// MARK: - Core Types

struct DocumentID<T>: Codable, Hashable, ExpressibleByStringLiteral {
    let rawValue: String
    init(_ rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: StringLiteralType) { self.rawValue = value }
}

enum ConvexEntity {
    enum Expense {}
    enum Incoming {}
    enum Recurring {}
    enum PaybackLink {}
    enum User {}
}

struct ISODateString: Codable, Hashable {
    let rawValue: String

    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ISODateString.isValid(trimmed) else { throw APIError.validation(message: "Date must be YYYY-MM-DD") }
        self.rawValue = trimmed
    }

    private static func isValid(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}

struct MonthKey: Codable, Hashable {
    let rawValue: String

    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MonthKey.isValid(trimmed) else { throw APIError.validation(message: "Month key must be YYYY-MM") }
        self.rawValue = trimmed
    }

    private static func isValid(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-(0[1-9]|1[0-2])$"#, options: .regularExpression) != nil
    }
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}
struct StringIDResponse: Decodable { let id: String }
struct UpdatedCountResponse: Decodable { let updated: Int }
struct DeletedCountResponse: Decodable { let deleted: Int; let baseExpenseId: String?; let done: Bool? }
struct InsertedCountResponse: Decodable { let inserted: Int }
struct MonthBoundsResponse: Decodable { let newestMonth: String?; let oldestMonth: String? }
struct UnlinkResponse: Decodable { let unlinked: Int; let remainingLinked: Int }
struct LinkResponse: Decodable { let linked: Int; let baseExpenseId: String?; let baseIncomingId: String?; let baseExpenseLabel: String? }
struct BulkPatchResultResponse: Decodable { let updatedCount: Int }

struct PaginationOpts: Codable {
    let cursor: String?
    let numItems: Int

    enum CodingKeys: String, CodingKey {
        case cursor
        case numItems
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let cursor {
            try container.encode(cursor, forKey: .cursor)
        } else {
            try container.encodeNil(forKey: .cursor)
        }
        try container.encode(numItems, forKey: .numItems)
    }
}
struct PaginationRequest: Codable { let paginationOpts: PaginationOpts }
struct PaginatedResponse<T: Decodable>: Decodable { let page: [T]; let isDone: Bool; let continueCursor: String? }

// MARK: - Protocols

protocol ConvexAPI {
    var auth: AuthAPI { get }
    var expenses: ExpensesAPI { get }
    var incomings: IncomingsAPI { get }
    var recurrings: RecurringsAPI { get }
    var summaries: SummariesAPI { get }
    var tracking: TrackingAPI { get }
    var notepad: NotepadAPI { get }
    var userOptions: UserOptionsAPI { get }
    var paybackLinks: PaybackLinksAPI { get }
}

protocol AuthAPI {
    func signIn(_ request: SignInRequest) async throws -> SessionResponse
    func signOut() async throws
    func session() async throws -> SessionResponse
}

protocol ExpensesAPI {
    func listByDateScope(_ request: DateScopeRequest) async throws -> [ExpenseDTO]
    func monthBounds() async throws -> MonthBoundsResponse
    func create(_ request: ExpenseMutationDTO) async throws -> DocumentID<ConvexEntity.Expense>
    func update(_ request: ExpenseUpdateDTO) async throws -> DocumentID<ConvexEntity.Expense>
    func remove(id: DocumentID<ConvexEntity.Expense>) async throws -> DocumentID<ConvexEntity.Expense>
    func bulkCreate(rows: [ExpenseMutationDTO]) async throws -> InsertedCountResponse
    func bulkPatchVisible(_ request: ExpenseBulkPatchRequest) async throws -> BulkPatchResultResponse
    func renameBaseExpense(_ request: RenameBaseExpenseRequest) async throws -> UpdatedCountResponse
    func removeBaseExpense(_ request: RemoveBaseExpenseRequest) async throws -> DeletedCountResponse
    func addPartnerExpense(_ request: AddPartnerExpenseRequest) async throws -> LinkResponse
    func unlinkExpenseFromPartners(_ request: UnlinkExpenseRequest) async throws -> UnlinkResponse
}

protocol IncomingsAPI {
    func listByDateScope(_ request: DateScopeRequest) async throws -> [IncomingDTO]
    func monthBounds() async throws -> MonthBoundsResponse
    func create(_ request: IncomingMutationDTO) async throws -> DocumentID<ConvexEntity.Incoming>
    func update(_ request: IncomingUpdateDTO) async throws -> DocumentID<ConvexEntity.Incoming>
    func remove(id: DocumentID<ConvexEntity.Incoming>) async throws -> DocumentID<ConvexEntity.Incoming>
    func bulkCreate(rows: [IncomingMutationDTO]) async throws -> InsertedCountResponse
    func bulkPatchVisible(_ request: IncomingBulkPatchRequest) async throws -> BulkPatchResultResponse
    func addPartnerIncoming(_ request: AddPartnerIncomingRequest) async throws -> LinkResponse
    func unlinkIncomingFromPartners(_ request: UnlinkIncomingRequest) async throws -> UnlinkResponse
}

protocol RecurringsAPI {
    func list(_ request: PaginationRequest) async throws -> PaginatedResponse<RecurringDTO>
    func create(_ request: RecurringMutationDTO) async throws -> DocumentID<ConvexEntity.Recurring>
    func update(_ request: RecurringUpdateDTO) async throws -> DocumentID<ConvexEntity.Recurring>
    func remove(id: DocumentID<ConvexEntity.Recurring>) async throws -> DocumentID<ConvexEntity.Recurring>
    func setStatus(_ request: SetRecurringStatusRequest) async throws -> DocumentID<ConvexEntity.Recurring>
    func materializeDueExpenses(runDate: String) async throws -> MaterializeResponse
    func cleanupRecurringKindFields() async throws -> UpdatedCountResponse
    func migrateLegacyRecurringsForUserIds(_ request: MigrateLegacyRecurringsRequest) async throws -> UpdatedCountResponse
}

protocol SummariesAPI { func range(_ request: SummaryRangeRequest) async throws -> SummaryRangeResponse }
protocol TrackingAPI { func list() async throws -> TrackingResponse }

protocol NotepadAPI {
    func getMine() async throws -> NotepadWorkspaceDTO
    func addNote(_ request: AddNoteRequest) async throws
    func cleanupEmptyNotes() async throws
    func renameNote(_ request: RenameNoteRequest) async throws
    func saveNoteContent(_ request: SaveNoteRequest) async throws
    func addTable() async throws
    func renameTable(_ request: RenameTableRequest) async throws
    func deleteTable(_ request: DeleteTableRequest) async throws
    func saveCell(_ request: SaveCellRequest) async throws
    func addRow(_ request: TableIDRequest) async throws
    func addColumn(_ request: TableIDRequest) async throws
    func removeLastRow(_ request: TableIDRequest) async throws
    func removeLastColumn(_ request: TableIDRequest) async throws
}

protocol UserOptionsAPI {
    func list() async throws -> UserOptionsListResponse
    func add(_ request: UserOptionAddRequest) async throws
    func updateColor(_ request: UserOptionUpdateColorRequest) async throws
    func remove(_ request: UserOptionRemoveRequest) async throws
    func setDefault(_ request: UserOptionSetDefaultRequest) async throws
    func setTracking(_ request: UserOptionSetTrackingRequest) async throws
    func rename(_ request: UserOptionRenameRequest) async throws
    func moveToSubtype(_ request: MoveToSubtypeRequest) async throws
    func promoteSubtype(_ request: PromoteSubtypeRequest) async throws
    func moveSubtype(_ request: MoveSubtypeRequest) async throws
}

protocol PaybackLinksAPI {
    func listForExpense(_ request: ExpenseIDRequest) async throws -> [PaybackExpenseLinkDTO]
    func listForIncoming(_ request: IncomingIDRequest) async throws -> [PaybackIncomingLinkDTO]
    func listIncomingCandidates() async throws -> [IncomingDTO]
    func listExpenseCandidates() async throws -> [ExpenseDTO]
    func create(_ request: PaybackLinkCreateRequest) async throws -> PaybackMutationResponse
    func update(_ request: PaybackLinkUpdateRequest) async throws -> PaybackMutationResponse
    func remove(_ request: PaybackLinkRemoveRequest) async throws -> DocumentID<ConvexEntity.PaybackLink>
}

// MARK: - DTOs

struct SignInRequest: Codable { let email: String; let password: String }
struct SessionResponse: Codable {
    let authenticated: Bool
    let userId: String?
    let token: String?
    let refreshToken: String?
}

struct DateScopeRequest: Codable {
    let startDate: String
    let endDate: String
    let targetMonths: [String]?
    let includeMonthYearOverlapOutsideDate: Bool?
}

struct ExpenseDTO: Codable {
    let _id: String
    let _creationTime: Double?
    let expense: String
    let type: String?
    let account: String?
    let category: String?
    let subcategory: String?
    let amount: Double
    let effectiveAmount: Double?
    let effectiveAmountMode: String?
    let monthYears: [String]
    let date: String
    let paidTo: String?
    let notes: String?
    let comments: String?
    let expenseId: String
    let baseExpenseId: String?
    let baseExpenseLabel: String?
    let subExpenseId: String?
}

struct IncomingDTO: Codable {
    let _id: String
    let _creationTime: Double?
    let incoming: String
    let paidBy: String?
    let incomeType: String?
    let incomeSubtype: String?
    let account: String?
    let amount: Double
    let effectiveAmount: Double?
    let effectiveAmountMode: String?
    let monthYears: [String]
    let date: String
    let notes: String?
    let comments: String?
    let incomingId: String
    let baseIncomingId: String?
    let subIncomingId: String?
}

struct ExpenseMutationDTO: Codable {
    let expense: String
    let type: String
    let account: String
    let category: String
    let subcategory: String?
    let amount: Double
    let effectiveAmount: Double?
    let effectiveAmountMode: String?
    let monthYears: [String]?
    let date: String
    let paidTo: String
    let notes: String?
    let comments: String?
    let expenseId: String
    let baseExpenseId: String?
    let baseExpenseLabel: String?
    let subExpenseId: String?
}

struct ExpenseUpdateDTO: Codable {
    let id: String
    let expense: String
    let type: String
    let account: String
    let category: String
    let subcategory: String?
    let amount: Double
    let effectiveAmount: Double?
    let effectiveAmountMode: String?
    let monthYears: [String]?
    let date: String
    let paidTo: String
    let notes: String?
    let comments: String?
    let expenseId: String
    let baseExpenseId: String?
    let baseExpenseLabel: String?
    let subExpenseId: String?
}

struct IncomingMutationDTO: Codable {
    let incoming: String
    let paidBy: String
    let incomeType: String
    let incomeSubtype: String?
    let account: String
    let amount: Double
    let effectiveAmount: Double?
    let effectiveAmountMode: String?
    let date: String
    let monthYears: [String]?
    let notes: String?
    let comments: String?
    let incomingId: String
    let baseIncomingId: String?
    let subIncomingId: String?
}

struct IncomingUpdateDTO: Codable {
    let id: String
    let incoming: String
    let paidBy: String
    let incomeType: String
    let incomeSubtype: String?
    let account: String
    let amount: Double
    let effectiveAmount: Double?
    let effectiveAmountMode: String?
    let date: String
    let monthYears: [String]?
    let notes: String?
    let comments: String?
    let incomingId: String
    let baseIncomingId: String?
    let subIncomingId: String?
}

struct ExpenseBulkPatchRequest: Codable { let ids: [String]; let patch: ExpensePatchDTO }
struct ExpensePatchDTO: Codable { let type: String?; let account: String?; let category: String?; let subcategory: String?; let paidTo: String?; let notes: String?; let comments: String? }

struct IncomingBulkPatchRequest: Codable { let ids: [String]; let patch: IncomingPatchDTO }
struct IncomingPatchDTO: Codable { let incomeType: String?; let incomeSubtype: String?; let account: String?; let paidBy: String?; let notes: String?; let comments: String? }

struct RenameBaseExpenseRequest: Codable { let baseExpenseId: String; let baseExpenseLabel: String }
struct RemoveBaseExpenseRequest: Codable { let baseExpenseId: String }
struct AddPartnerExpenseRequest: Codable { let anchorExpenseId: String; let partnerExpenseId: String }
struct UnlinkExpenseRequest: Codable { let expenseId: String }

struct AddPartnerIncomingRequest: Codable { let anchorIncomingId: String; let partnerIncomingId: String }
struct UnlinkIncomingRequest: Codable { let incomingId: String }

struct RecurringDTO: Codable {
    let _id: String
    let _creationTime: Double?
    let status: String
    let kind: String?
    let name: String
    let amount: Double
    let frequency: String
    let dayOfMonth: Int
    let recurringExpenseType: String?
    let recurringExpenseAccount: String?
    let recurringExpenseCategory: String?
    let recurringExpenseSubcategory: String?
    let recurringExpensePaidTo: String?
    let recurringIncomingPaidBy: String?
    let recurringIncomingType: String?
    let recurringIncomingSubtype: String?
    let recurringIncomingAccount: String?
    let notes: String?
}

struct RecurringMutationDTO: Codable {
    let status: String
    let kind: String
    let name: String
    let amount: Double
    let frequency: String
    let dayOfMonth: Int
    let recurringExpenseType: String?
    let recurringExpenseAccount: String?
    let recurringExpenseCategory: String?
    let recurringExpenseSubcategory: String?
    let recurringExpensePaidTo: String?
    let recurringIncomingPaidBy: String?
    let recurringIncomingType: String?
    let recurringIncomingSubtype: String?
    let recurringIncomingAccount: String?
    let notes: String?
}

struct RecurringUpdateDTO: Codable {
    let id: String
    let status: String
    let kind: String
    let name: String
    let amount: Double
    let frequency: String
    let dayOfMonth: Int
    let recurringExpenseType: String?
    let recurringExpenseAccount: String?
    let recurringExpenseCategory: String?
    let recurringExpenseSubcategory: String?
    let recurringExpensePaidTo: String?
    let recurringIncomingPaidBy: String?
    let recurringIncomingType: String?
    let recurringIncomingSubtype: String?
    let recurringIncomingAccount: String?
    let notes: String?
}

struct SetRecurringStatusRequest: Codable { let id: String; let status: String }
struct MigrateLegacyRecurringsRequest: Codable { let userId: String; let ids: [String] }
struct MaterializeResponse: Codable { let runDate: String; let day: Int; let matched: Int; let created: Int; let skipped: Int }

struct SummaryRangeRequest: Codable { let startDate: String; let endDate: String }
struct SummaryRangeResponse: Codable { let startDate: String; let endDate: String; let totals: SummaryTotals; let monthlyBuckets: [SummaryBucket] }
struct SummaryTotals: Codable { let rawExpenses: Double; let effectiveExpenses: Double; let rawIncomings: Double; let effectiveIncomings: Double; let rawNet: Double; let effectiveNet: Double }
struct SummaryBucket: Codable { let month: String; let rawExpenses: Double; let effectiveExpenses: Double; let rawIncomings: Double; let effectiveIncomings: Double; let rawNet: Double; let effectiveNet: Double }

struct TrackingResponse: Codable { let currentMonth: String; let rows: [TrackingRow] }
struct TrackingRow: Codable { let key: String; let source: String; let kind: String; let value: String; let parentValue: String?; let color: String; let label: String; let paidMonths: [String]; let rangeMonths: [String]; let statusByMonth: [String: String] }

struct NotepadWorkspaceDTO: Codable { let _id: String?; let _creationTime: Double?; let userId: String?; let notes: [NotepadNote]; let tables: [NotepadTable]; let updatedAt: Double }
struct NotepadNote: Codable { let id: String; let title: String; let content: String }
struct NotepadTable: Codable { let id: String; let title: String; let cells: [[String]] }

struct AddNoteRequest: Codable { let noteId: String?; let title: String? }
struct RenameNoteRequest: Codable { let noteId: String; let title: String }
struct SaveNoteRequest: Codable { let noteId: String; let content: String }
struct RenameTableRequest: Codable { let tableId: String; let title: String }
struct DeleteTableRequest: Codable { let tableId: String }
struct SaveCellRequest: Codable { let tableId: String; let rowIndex: Int; let colIndex: Int; let value: String }
struct TableIDRequest: Codable { let tableId: String }

struct UserOptionsListResponse: Codable {
    let expenseType: [UserOptionRow]
    let account: [UserOptionRow]
    let category: [UserOptionRow]
    let subcategory: [UserOptionRow]
    let incomeType: [UserOptionRow]
    let incomeSubtype: [UserOptionRow]
}

struct UserOptionRow: Codable { let value: String; let color: String; let isDefault: Bool; let isTracking: Bool; let parentValue: String? }

struct UserOptionAddRequest: Codable { let kind: String; let value: String; let parentValue: String? }
struct UserOptionUpdateColorRequest: Codable { let kind: String; let value: String; let color: String; let parentValue: String? }
struct UserOptionRemoveRequest: Codable { let kind: String; let value: String; let parentValue: String? }
struct UserOptionSetDefaultRequest: Codable { let kind: String; let value: String; let isDefault: Bool; let parentValue: String? }
struct UserOptionSetTrackingRequest: Codable { let kind: String; let value: String; let isTracking: Bool; let parentValue: String? }
struct UserOptionRenameRequest: Codable { let kind: String; let value: String; let nextValue: String; let parentValue: String? }
struct MoveToSubtypeRequest: Codable { let kind: String; let sourceValue: String; let targetValue: String }
struct PromoteSubtypeRequest: Codable { let kind: String; let value: String; let parentValue: String }
struct MoveSubtypeRequest: Codable { let kind: String; let value: String; let sourceParentValue: String; let targetParentValue: String }

struct ExpenseIDRequest: Codable { let expenseId: String }
struct IncomingIDRequest: Codable { let incomingId: String }
struct PaybackLinkCreateRequest: Codable { let expenseId: String; let incomingId: String; let allocatedAmount: Double; let notes: String? }
struct PaybackLinkUpdateRequest: Codable { let id: String; let allocatedAmount: Double; let notes: String? }
struct PaybackLinkRemoveRequest: Codable { let id: String }
struct PaybackMutationResponse: Codable { let id: String; let warnings: [String] }

struct PaybackExpenseLinkDTO: Codable {
    let _id: String
    let expenseId: String
    let incomingId: String
    let allocatedAmount: Double
    let notes: String?
    let createdAt: Double
    let updatedAt: Double
    let incoming: IncomingDTO
}

struct PaybackIncomingLinkDTO: Codable {
    let _id: String
    let expenseId: String
    let incomingId: String
    let allocatedAmount: Double
    let notes: String?
    let createdAt: Double
    let updatedAt: Double
    let expense: ExpenseDTO
}

// MARK: - Service

final class ConvexService: ConvexAPI {
    let auth: AuthAPI
    let expenses: ExpensesAPI
    let incomings: IncomingsAPI
    let recurrings: RecurringsAPI
    let summaries: SummariesAPI
    let tracking: TrackingAPI
    let notepad: NotepadAPI
    let userOptions: UserOptionsAPI
    let paybackLinks: PaybackLinksAPI

    init(client: HTTPClientProtocol) {
        auth = AuthClient(client: client)
        expenses = ExpensesClient(client: client)
        incomings = IncomingsClient(client: client)
        recurrings = RecurringsClient(client: client)
        summaries = SummariesClient(client: client)
        tracking = TrackingClient(client: client)
        notepad = NotepadClient(client: client)
        userOptions = UserOptionsClient(client: client)
        paybackLinks = PaybackLinksClient(client: client)
    }
}

private struct IDPayload: Codable { let id: String }
private struct RowsPayload<T: Codable>: Codable { let rows: [T] }

private enum Req {
    static func get(_ path: String) -> HTTPRequestSpec { .init(endpoint: path, method: .get, isIdempotent: true, isMutation: false) }
    static func query(_ path: String) -> HTTPRequestSpec { .init(endpoint: path, method: .post, isIdempotent: true, isMutation: false) }
    static func mutation(_ path: String) -> HTTPRequestSpec { .init(endpoint: path, method: .post, isIdempotent: false, isMutation: true) }
}

private final class AuthClient: AuthAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func signIn(_ request: SignInRequest) async throws -> SessionResponse { try await client.send(Req.mutation("api/auth/sign-in"), body: request) }
    func signOut() async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/auth/sign-out"), body: EmptyBody()) }
    func session() async throws -> SessionResponse { try await client.send(Req.get("api/auth/session"), body: Optional<EmptyBody>.none) }
}

private final class ExpensesClient: ExpensesAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func listByDateScope(_ request: DateScopeRequest) async throws -> [ExpenseDTO] { try await client.send(Req.query("api/expenses/list-by-date-scope"), body: request) }
    func monthBounds() async throws -> MonthBoundsResponse { try await client.send(Req.get("api/expenses/month-bounds"), body: Optional<EmptyBody>.none) }
    func create(_ request: ExpenseMutationDTO) async throws -> DocumentID<ConvexEntity.Expense> { DocumentID(try await client.send(Req.mutation("api/expenses/create"), body: request) as String) }
    func update(_ request: ExpenseUpdateDTO) async throws -> DocumentID<ConvexEntity.Expense> { DocumentID(try await client.send(Req.mutation("api/expenses/update"), body: request) as String) }
    func remove(id: DocumentID<ConvexEntity.Expense>) async throws -> DocumentID<ConvexEntity.Expense> { DocumentID(try await client.send(Req.mutation("api/expenses/remove"), body: IDPayload(id: id.rawValue)) as String) }
    func bulkCreate(rows: [ExpenseMutationDTO]) async throws -> InsertedCountResponse { try await client.send(Req.mutation("api/expenses/bulk-create"), body: RowsPayload(rows: rows)) }
    func bulkPatchVisible(_ request: ExpenseBulkPatchRequest) async throws -> BulkPatchResultResponse { try await client.send(Req.mutation("api/expenses/bulk-patch-visible"), body: request) }
    func renameBaseExpense(_ request: RenameBaseExpenseRequest) async throws -> UpdatedCountResponse { try await client.send(Req.mutation("api/expenses/rename-base-expense"), body: request) }
    func removeBaseExpense(_ request: RemoveBaseExpenseRequest) async throws -> DeletedCountResponse { try await client.send(Req.mutation("api/expenses/remove-base-expense"), body: request) }
    func addPartnerExpense(_ request: AddPartnerExpenseRequest) async throws -> LinkResponse { try await client.send(Req.mutation("api/expenses/add-partner-expense"), body: request) }
    func unlinkExpenseFromPartners(_ request: UnlinkExpenseRequest) async throws -> UnlinkResponse { try await client.send(Req.mutation("api/expenses/unlink-expense-from-partners"), body: request) }
}

private final class IncomingsClient: IncomingsAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func listByDateScope(_ request: DateScopeRequest) async throws -> [IncomingDTO] { try await client.send(Req.query("api/incomings/list-by-date-scope"), body: request) }
    func monthBounds() async throws -> MonthBoundsResponse { try await client.send(Req.get("api/incomings/month-bounds"), body: Optional<EmptyBody>.none) }
    func create(_ request: IncomingMutationDTO) async throws -> DocumentID<ConvexEntity.Incoming> { DocumentID(try await client.send(Req.mutation("api/incomings/create"), body: request) as String) }
    func update(_ request: IncomingUpdateDTO) async throws -> DocumentID<ConvexEntity.Incoming> { DocumentID(try await client.send(Req.mutation("api/incomings/update"), body: request) as String) }
    func remove(id: DocumentID<ConvexEntity.Incoming>) async throws -> DocumentID<ConvexEntity.Incoming> { DocumentID(try await client.send(Req.mutation("api/incomings/remove"), body: IDPayload(id: id.rawValue)) as String) }
    func bulkCreate(rows: [IncomingMutationDTO]) async throws -> InsertedCountResponse { try await client.send(Req.mutation("api/incomings/bulk-create"), body: RowsPayload(rows: rows)) }
    func bulkPatchVisible(_ request: IncomingBulkPatchRequest) async throws -> BulkPatchResultResponse { try await client.send(Req.mutation("api/incomings/bulk-patch-visible"), body: request) }
    func addPartnerIncoming(_ request: AddPartnerIncomingRequest) async throws -> LinkResponse { try await client.send(Req.mutation("api/incomings/add-partner-incoming"), body: request) }
    func unlinkIncomingFromPartners(_ request: UnlinkIncomingRequest) async throws -> UnlinkResponse { try await client.send(Req.mutation("api/incomings/unlink-incoming-from-partners"), body: request) }
}

private final class RecurringsClient: RecurringsAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func list(_ request: PaginationRequest) async throws -> PaginatedResponse<RecurringDTO> { try await client.send(Req.query("api/recurrings/list"), body: request) }
    func create(_ request: RecurringMutationDTO) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID(try await client.send(Req.mutation("api/recurrings/create"), body: request) as String) }
    func update(_ request: RecurringUpdateDTO) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID(try await client.send(Req.mutation("api/recurrings/update"), body: request) as String) }
    func remove(id: DocumentID<ConvexEntity.Recurring>) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID(try await client.send(Req.mutation("api/recurrings/remove"), body: IDPayload(id: id.rawValue)) as String) }
    func setStatus(_ request: SetRecurringStatusRequest) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID(try await client.send(Req.mutation("api/recurrings/set-status"), body: request) as String) }
    func materializeDueExpenses(runDate: String) async throws -> MaterializeResponse { try await client.send(Req.mutation("api/recurrings/materialize-due-expenses"), body: ["runDate": runDate]) }
    func cleanupRecurringKindFields() async throws -> UpdatedCountResponse { try await client.send(Req.mutation("api/recurrings/cleanup-recurring-kind-fields"), body: EmptyBody()) }
    func migrateLegacyRecurringsForUserIds(_ request: MigrateLegacyRecurringsRequest) async throws -> UpdatedCountResponse { try await client.send(Req.mutation("api/recurrings/migrate-legacy-recurrings-for-user-ids"), body: request) }
}

private final class SummariesClient: SummariesAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func range(_ request: SummaryRangeRequest) async throws -> SummaryRangeResponse { try await client.send(Req.query("api/summaries/range"), body: request) }
}

private final class TrackingClient: TrackingAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func list() async throws -> TrackingResponse { try await client.send(Req.get("api/tracking/list"), body: Optional<EmptyBody>.none) }
}

private final class NotepadClient: NotepadAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func getMine() async throws -> NotepadWorkspaceDTO { try await client.send(Req.get("api/notepad/get-mine"), body: Optional<EmptyBody>.none) }
    func addNote(_ request: AddNoteRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/add-note"), body: request) }
    func cleanupEmptyNotes() async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/cleanup-empty-notes"), body: EmptyBody()) }
    func renameNote(_ request: RenameNoteRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/rename-note"), body: request) }
    func saveNoteContent(_ request: SaveNoteRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/save-note-content"), body: request) }
    func addTable() async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/add-table"), body: EmptyBody()) }
    func renameTable(_ request: RenameTableRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/rename-table"), body: request) }
    func deleteTable(_ request: DeleteTableRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/delete-table"), body: request) }
    func saveCell(_ request: SaveCellRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/save-cell"), body: request) }
    func addRow(_ request: TableIDRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/add-row"), body: request) }
    func addColumn(_ request: TableIDRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/add-column"), body: request) }
    func removeLastRow(_ request: TableIDRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/remove-last-row"), body: request) }
    func removeLastColumn(_ request: TableIDRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/notepad/remove-last-column"), body: request) }
}

private final class UserOptionsClient: UserOptionsAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func list() async throws -> UserOptionsListResponse { try await client.send(Req.get("api/user-options/list"), body: Optional<EmptyBody>.none) }
    func add(_ request: UserOptionAddRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/add"), body: request) }
    func updateColor(_ request: UserOptionUpdateColorRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/update-color"), body: request) }
    func remove(_ request: UserOptionRemoveRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/remove"), body: request) }
    func setDefault(_ request: UserOptionSetDefaultRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/set-default"), body: request) }
    func setTracking(_ request: UserOptionSetTrackingRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/set-tracking"), body: request) }
    func rename(_ request: UserOptionRenameRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/rename"), body: request) }
    func moveToSubtype(_ request: MoveToSubtypeRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/move-to-subtype"), body: request) }
    func promoteSubtype(_ request: PromoteSubtypeRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/promote-subtype"), body: request) }
    func moveSubtype(_ request: MoveSubtypeRequest) async throws { let _: EmptyResponse = try await client.send(Req.mutation("api/user-options/move-subtype"), body: request) }
}

private final class PaybackLinksClient: PaybackLinksAPI {
    private let client: HTTPClientProtocol
    init(client: HTTPClientProtocol) { self.client = client }

    func listForExpense(_ request: ExpenseIDRequest) async throws -> [PaybackExpenseLinkDTO] { try await client.send(Req.query("api/payback-links/list-for-expense"), body: request) }
    func listForIncoming(_ request: IncomingIDRequest) async throws -> [PaybackIncomingLinkDTO] { try await client.send(Req.query("api/payback-links/list-for-incoming"), body: request) }
    func listIncomingCandidates() async throws -> [IncomingDTO] { try await client.send(Req.get("api/payback-links/list-incoming-candidates"), body: Optional<EmptyBody>.none) }
    func listExpenseCandidates() async throws -> [ExpenseDTO] { try await client.send(Req.get("api/payback-links/list-expense-candidates"), body: Optional<EmptyBody>.none) }
    func create(_ request: PaybackLinkCreateRequest) async throws -> PaybackMutationResponse { try await client.send(Req.mutation("api/payback-links/create"), body: request) }
    func update(_ request: PaybackLinkUpdateRequest) async throws -> PaybackMutationResponse { try await client.send(Req.mutation("api/payback-links/update"), body: request) }
    func remove(_ request: PaybackLinkRemoveRequest) async throws -> DocumentID<ConvexEntity.PaybackLink> { DocumentID(try await client.send(Req.mutation("api/payback-links/remove"), body: request) as String) }
}
