import XCTest
@testable import Pensive

final class LedgerPart6Tests: XCTestCase {
    func testScopeMatchStatusVariants() throws {
        let start = try XCTUnwrap(LedgerScopeLogic.parseISODate("2026-05-01"))
        let end = try XCTUnwrap(LedgerScopeLogic.parseISODate("2026-05-31"))
        let scope = DateScope(startDate: start, endDate: end, includeMonthYearOverlapOutsideDate: true)

        let fullDate = try XCTUnwrap(LedgerScopeLogic.parseISODate("2026-05-10"))
        XCTAssertEqual(LedgerScopeLogic.scopeStatus(date: fullDate, monthYears: [MonthYear("2026-05")!], scope: scope), .full)

        let monthOnlyDate = try XCTUnwrap(LedgerScopeLogic.parseISODate("2026-04-30"))
        XCTAssertEqual(LedgerScopeLogic.scopeStatus(date: monthOnlyDate, monthYears: [MonthYear("2026-05")!], scope: scope), .monthYearsOnly)

        let dateOnly = try XCTUnwrap(LedgerScopeLogic.parseISODate("2026-05-03"))
        XCTAssertEqual(LedgerScopeLogic.scopeStatus(date: dateOnly, monthYears: [MonthYear("2026-06")!], scope: scope), .dateOnly)
    }

    func testExpenseFilteringBySearchAndFilterSet() {
        let expenseA = Expense(id: "1", name: "Rent", type: "Fixed", account: "Bank", category: "Home", subcategory: nil, amount: 1000, effectiveAmount: 1000, effectiveAmountMode: .auto, monthYears: [MonthYear("2026-05")!], date: Date(), paidTo: "Owner", notes: "monthly", comments: nil, expenseId: "e1", baseExpenseId: nil, baseExpenseLabel: nil, subExpenseId: nil)
        let expenseB = Expense(id: "2", name: "Coffee", type: "Food", account: "Cash", category: "Lifestyle", subcategory: nil, amount: 20, effectiveAmount: 20, effectiveAmountMode: .auto, monthYears: [MonthYear("2026-05")!], date: Date(), paidTo: "Cafe", notes: nil, comments: nil, expenseId: "e2", baseExpenseId: nil, baseExpenseLabel: nil, subExpenseId: nil)

        XCTAssertEqual(LedgerFiltering.filterExpenses([expenseA, expenseB], selected: ["Bank"], searchText: "rent").map(\.id), ["1"])
        XCTAssertEqual(LedgerFiltering.filterExpenses([expenseA, expenseB], selected: [], searchText: "cafe").map(\.id), ["2"])
    }

    @MainActor
    func testExpenseCRUDBulkAndPartnerOperationsCallAPI() async {
        let api = MockConvexAPI()
        let vm = LedgerFeatureViewModel(kind: .expense, api: api)

        let createDraft = ExpenseEditorDraft(id: nil, expense: "X", type: "T", account: "A", category: "C", subcategory: nil, amount: 5, effectiveAmount: 5, effectiveAmountMode: .auto, date: LedgerScopeLogic.parseISODate("2026-05-01")!, paidTo: "P", notes: nil, comments: nil, expenseId: "eid", baseExpenseId: nil, baseExpenseLabel: nil, subExpenseId: nil)
        vm.createExpense(createDraft)

        var updateDraft = createDraft
        updateDraft.id = "id1"
        updateDraft.expense = "Y"
        vm.updateExpense(updateDraft)

        vm.bulkCreateExpenses([createDraft, createDraft])
        vm.addPartner(anchorID: "a", partnerID: "b")
        vm.unlinkPartner(id: "a")
        vm.renameExpenseBaseGroup(baseID: "base", label: "House")
        vm.removeExpenseBaseGroup(baseID: "base")
        vm.delete(id: "id1")

        try? await Task.sleep(nanoseconds: 160_000_000)

        XCTAssertEqual(api.createExpenseCalls, 1)
        XCTAssertEqual(api.updateExpenseCalls, 1)
        XCTAssertEqual(api.bulkCreateExpenseCalls, 1)
        XCTAssertEqual(api.addPartnerExpenseCalls, 1)
        XCTAssertEqual(api.unlinkExpenseCalls, 1)
        XCTAssertEqual(api.renameBaseExpenseCalls, 1)
        XCTAssertEqual(api.removeBaseExpenseCalls, 1)
        XCTAssertEqual(api.removeExpenseCalls, 1)
    }

    @MainActor
    func testAddMissingOptionCallsAPI() async {
        let api = MockConvexAPI()
        let vm = LedgerFeatureViewModel(kind: .expense, api: api)
        await vm.addMissingOption(kind: "category", value: "Travel")
        XCTAssertEqual(api.addUserOptionCalls, 1)
    }
}

private final class MockConvexAPI: ConvexAPI {
    let auth: AuthAPI = NoopAuthAPI()
    let expenses: ExpensesAPI
    let incomings: IncomingsAPI
    let recurrings: RecurringsAPI = NoopRecurringsAPI()
    let summaries: SummariesAPI = NoopSummariesAPI()
    let tracking: TrackingAPI = NoopTrackingAPI()
    let notepad: NotepadAPI = NoopNotepadAPI()
    let userOptions: UserOptionsAPI
    let paybackLinks: PaybackLinksAPI = NoopPaybackAPI()

    private let expenseClient: MockExpensesClient
    private let optionsClient: MockUserOptionsClient

    var createExpenseCalls: Int { expenseClient.createCalls }
    var updateExpenseCalls: Int { expenseClient.updateCalls }
    var bulkCreateExpenseCalls: Int { expenseClient.bulkCreateCalls }
    var addPartnerExpenseCalls: Int { expenseClient.addPartnerCalls }
    var unlinkExpenseCalls: Int { expenseClient.unlinkCalls }
    var renameBaseExpenseCalls: Int { expenseClient.renameBaseCalls }
    var removeBaseExpenseCalls: Int { expenseClient.removeBaseCalls }
    var removeExpenseCalls: Int { expenseClient.removeCalls }
    var addUserOptionCalls: Int { optionsClient.addCalls }

    init() {
        let expenseClient = MockExpensesClient()
        self.expenseClient = expenseClient
        self.expenses = expenseClient
        self.incomings = MockIncomingsClient()

        let optionsClient = MockUserOptionsClient()
        self.optionsClient = optionsClient
        self.userOptions = optionsClient
    }
}

private final class MockExpensesClient: ExpensesAPI {
    var createCalls = 0
    var updateCalls = 0
    var bulkCreateCalls = 0
    var addPartnerCalls = 0
    var unlinkCalls = 0
    var renameBaseCalls = 0
    var removeBaseCalls = 0
    var removeCalls = 0

    func listByDateScope(_ request: DateScopeRequest) async throws -> [ExpenseDTO] { [] }
    func monthBounds() async throws -> MonthBoundsResponse { .init(newestMonth: nil, oldestMonth: nil) }
    func create(_ request: ExpenseMutationDTO) async throws -> DocumentID<ConvexEntity.Expense> { createCalls += 1; return DocumentID("id") }
    func update(_ request: ExpenseUpdateDTO) async throws -> DocumentID<ConvexEntity.Expense> { updateCalls += 1; return DocumentID("id") }
    func remove(id: DocumentID<ConvexEntity.Expense>) async throws -> DocumentID<ConvexEntity.Expense> { removeCalls += 1; return id }
    func bulkCreate(rows: [ExpenseMutationDTO]) async throws -> InsertedCountResponse { bulkCreateCalls += 1; return .init(inserted: rows.count) }
    func bulkPatchVisible(_ request: ExpenseBulkPatchRequest) async throws -> BulkPatchResultResponse { .init(updatedCount: request.ids.count) }
    func renameBaseExpense(_ request: RenameBaseExpenseRequest) async throws -> UpdatedCountResponse { renameBaseCalls += 1; return .init(updated: 1) }
    func removeBaseExpense(_ request: RemoveBaseExpenseRequest) async throws -> DeletedCountResponse { removeBaseCalls += 1; return .init(deleted: 1, baseExpenseId: request.baseExpenseId, done: true) }
    func addPartnerExpense(_ request: AddPartnerExpenseRequest) async throws -> LinkResponse { addPartnerCalls += 1; return .init(linked: 1, baseExpenseId: "b", baseIncomingId: nil, baseExpenseLabel: nil) }
    func unlinkExpenseFromPartners(_ request: UnlinkExpenseRequest) async throws -> UnlinkResponse { unlinkCalls += 1; return .init(unlinked: 1, remainingLinked: 0) }
}

private final class MockIncomingsClient: IncomingsAPI {
    func listByDateScope(_ request: DateScopeRequest) async throws -> [IncomingDTO] { [] }
    func monthBounds() async throws -> MonthBoundsResponse { .init(newestMonth: nil, oldestMonth: nil) }
    func create(_ request: IncomingMutationDTO) async throws -> DocumentID<ConvexEntity.Incoming> { DocumentID("id") }
    func update(_ request: IncomingUpdateDTO) async throws -> DocumentID<ConvexEntity.Incoming> { DocumentID("id") }
    func remove(id: DocumentID<ConvexEntity.Incoming>) async throws -> DocumentID<ConvexEntity.Incoming> { id }
    func bulkCreate(rows: [IncomingMutationDTO]) async throws -> InsertedCountResponse { .init(inserted: rows.count) }
    func bulkPatchVisible(_ request: IncomingBulkPatchRequest) async throws -> BulkPatchResultResponse { .init(updatedCount: request.ids.count) }
    func addPartnerIncoming(_ request: AddPartnerIncomingRequest) async throws -> LinkResponse { .init(linked: 1, baseExpenseId: nil, baseIncomingId: "b", baseExpenseLabel: nil) }
    func unlinkIncomingFromPartners(_ request: UnlinkIncomingRequest) async throws -> UnlinkResponse { .init(unlinked: 1, remainingLinked: 0) }
}

private final class MockUserOptionsClient: UserOptionsAPI {
    var addCalls = 0

    func list() async throws -> UserOptionsListResponse { .init(expenseType: [], account: [], category: [], subcategory: [], incomeType: [], incomeSubtype: []) }
    func add(_ request: UserOptionAddRequest) async throws { addCalls += 1 }
    func updateColor(_ request: UserOptionUpdateColorRequest) async throws {}
    func remove(_ request: UserOptionRemoveRequest) async throws {}
    func setDefault(_ request: UserOptionSetDefaultRequest) async throws {}
    func setTracking(_ request: UserOptionSetTrackingRequest) async throws {}
    func rename(_ request: UserOptionRenameRequest) async throws {}
    func moveToSubtype(_ request: MoveToSubtypeRequest) async throws {}
    func promoteSubtype(_ request: PromoteSubtypeRequest) async throws {}
    func moveSubtype(_ request: MoveSubtypeRequest) async throws {}
}

private struct NoopAuthAPI: AuthAPI { func signIn(_ request: SignInRequest) async throws -> SessionResponse { .init(authenticated: true, userId: "u", token: nil, refreshToken: nil) }; func signOut() async throws {}; func session() async throws -> SessionResponse { .init(authenticated: true, userId: "u", token: nil, refreshToken: nil) } }
private struct NoopRecurringsAPI: RecurringsAPI { func list(_ request: PaginationRequest) async throws -> PaginatedResponse<RecurringDTO> { .init(page: [], isDone: true, continueCursor: nil) }; func create(_ request: RecurringMutationDTO) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID("id") }; func update(_ request: RecurringUpdateDTO) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID("id") }; func remove(id: DocumentID<ConvexEntity.Recurring>) async throws -> DocumentID<ConvexEntity.Recurring> { id }; func setStatus(_ request: SetRecurringStatusRequest) async throws -> DocumentID<ConvexEntity.Recurring> { DocumentID(request.id) }; func materializeDueExpenses(runDate: String) async throws -> MaterializeResponse { .init(runDate: runDate, day: 1, matched: 0, created: 0, skipped: 0) }; func cleanupRecurringKindFields() async throws -> UpdatedCountResponse { .init(updated: 0) }; func migrateLegacyRecurringsForUserIds(_ request: MigrateLegacyRecurringsRequest) async throws -> UpdatedCountResponse { .init(updated: 0) } }
private struct NoopSummariesAPI: SummariesAPI { func range(_ request: SummaryRangeRequest) async throws -> SummaryRangeResponse { .init(startDate: request.startDate, endDate: request.endDate, totals: .init(rawExpenses: 0, effectiveExpenses: 0, rawIncomings: 0, effectiveIncomings: 0, rawNet: 0, effectiveNet: 0), monthlyBuckets: []) } }
private struct NoopTrackingAPI: TrackingAPI { func list() async throws -> TrackingResponse { .init(currentMonth: "2026-05", rows: []) } }
private struct NoopNotepadAPI: NotepadAPI { func getMine() async throws -> NotepadWorkspaceDTO { .init(_id: nil, _creationTime: nil, userId: nil, notes: [], tables: [], updatedAt: 0) }; func addNote(_ request: AddNoteRequest) async throws {}; func cleanupEmptyNotes() async throws {}; func renameNote(_ request: RenameNoteRequest) async throws {}; func saveNoteContent(_ request: SaveNoteRequest) async throws {}; func addTable() async throws {}; func renameTable(_ request: RenameTableRequest) async throws {}; func deleteTable(_ request: DeleteTableRequest) async throws {}; func saveCell(_ request: SaveCellRequest) async throws {}; func addRow(_ request: TableIDRequest) async throws {}; func addColumn(_ request: TableIDRequest) async throws {}; func removeLastRow(_ request: TableIDRequest) async throws {}; func removeLastColumn(_ request: TableIDRequest) async throws {} }
private struct NoopPaybackAPI: PaybackLinksAPI { func listForExpense(_ request: ExpenseIDRequest) async throws -> [PaybackExpenseLinkDTO] { [] }; func listForIncoming(_ request: IncomingIDRequest) async throws -> [PaybackIncomingLinkDTO] { [] }; func listIncomingCandidates() async throws -> [IncomingDTO] { [] }; func listExpenseCandidates() async throws -> [ExpenseDTO] { [] }; func create(_ request: PaybackLinkCreateRequest) async throws -> PaybackMutationResponse { .init(id: "id", warnings: []) }; func update(_ request: PaybackLinkUpdateRequest) async throws -> PaybackMutationResponse { .init(id: "id", warnings: []) }; func remove(_ request: PaybackLinkRemoveRequest) async throws -> DocumentID<ConvexEntity.PaybackLink> { DocumentID(request.id) } }
