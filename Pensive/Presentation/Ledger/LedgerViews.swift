import SwiftUI

struct ExpensesFeatureView: View {
    @StateObject private var viewModel: LedgerFeatureViewModel

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: LedgerFeatureViewModel(kind: .expense, api: api))
    }

    var body: some View {
        LedgerScreen(viewModel: viewModel)
            .navigationTitle("Expenses")
    }
}

struct IncomingsFeatureView: View {
    @StateObject private var viewModel: LedgerFeatureViewModel

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: LedgerFeatureViewModel(kind: .incoming, api: api))
    }

    var body: some View {
        LedgerScreen(viewModel: viewModel)
            .navigationTitle("Incomings")
    }
}

enum PaybackTarget {
    case expense(String)
    case incoming(String)
}

private struct LedgerScreen: View {
    @ObservedObject var viewModel: LedgerFeatureViewModel

    @State private var showCreate = false
    @State private var showBulkCreate = false
    @State private var editingID: RowID?
    @State private var deleteID: String?
    @State private var selectedPartnerAnchorID: RowID?

    var body: some View {
        LoadStateView(state: viewModel.state, retry: { Task { await viewModel.refresh() } }) {
            List {
                Section {
                    DebouncedSearchField(text: $viewModel.searchText) { viewModel.applySearch($0) }
                    MultiSelectFilterButton(title: "Filters", choices: filterChoices, selected: Binding(get: { viewModel.selectedFilters }, set: { viewModel.updateFilters($0) }))
                    DateRangePickerButton(startDate: $viewModel.scope.startDate, endDate: $viewModel.scope.endDate)
                    Toggle("Include month overlap", isOn: $viewModel.scope.includeMonthYearOverlapOutsideDate)
                        .onChange(of: viewModel.scope) { _, _ in viewModel.updateScope() }
                }

                ForEach(viewModel.rows) { row in
                    DisclosureGroup {
                        ForEach(row.details, id: \.self) { detail in
                            Text(detail).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("Month Years: \(row.monthYears.joined(separator: ", "))").font(.footnote)

                        HStack {
                            Button("Add partner") { selectedPartnerAnchorID = RowID(id: row.id) }
                            Button("Unlink partner") { viewModel.unlinkPartner(id: row.id) }
                        }

                        if viewModel.kind == .expense {
                            Button("Rename base group") { viewModel.renameExpenseBaseGroup(baseID: row.id, label: row.title) }
                            Button("Remove base group", role: .destructive) { viewModel.removeExpenseBaseGroup(baseID: row.id) }
                        }

                        NavigationLink("Manage Payback Links") {
                            PaybackLinksManagerView(target: viewModel.kind == .expense ? .expense(row.id) : .incoming(row.id), viewModel: viewModel)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title).font(.headline)
                            Text(row.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            Text(row.amountLine).font(.subheadline.weight(.medium))
                            Text(row.appliedLine).font(.footnote).foregroundStyle(.secondary)
                            if let warning = row.warningText {
                                Text(warning).font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Edit") { editingID = RowID(id: row.id) }.tint(.blue)
                        Button(role: .destructive) { deleteID = row.id } label: { Text("Delete") }
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showBulkCreate = true } label: { Image(systemName: "square.stack.3d.up") }
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showCreate) {
                if viewModel.kind == .expense {
                    ExpenseEditorSheet(viewModel: viewModel, initialDraft: ExpenseEditorDraft(id: nil, expense: "", type: "", account: "", category: "", subcategory: nil, amount: 0, effectiveAmount: 0, effectiveAmountMode: .auto, date: Date(), paidTo: "", notes: nil, comments: nil, expenseId: UUID().uuidString, baseExpenseId: nil, baseExpenseLabel: nil, subExpenseId: nil), mode: .create)
                } else {
                    IncomingEditorSheet(viewModel: viewModel, initialDraft: IncomingEditorDraft(id: nil, incoming: "", paidBy: "", incomeType: "", incomeSubtype: nil, account: "", amount: 0, effectiveAmount: 0, effectiveAmountMode: .auto, date: Date(), notes: nil, comments: nil, incomingId: UUID().uuidString, baseIncomingId: nil, subIncomingId: nil), mode: .create)
                }
            }
            .sheet(isPresented: $showBulkCreate) {
                BulkCreateSheet(kind: viewModel.kind, viewModel: viewModel)
            }
            .sheet(item: $editingID) { selected in
                if viewModel.kind == .expense, let draft = viewModel.expenseDraft(id: selected.id) {
                    ExpenseEditorSheet(viewModel: viewModel, initialDraft: draft, mode: .edit)
                } else if viewModel.kind == .incoming, let draft = viewModel.incomingDraft(id: selected.id) {
                    IncomingEditorSheet(viewModel: viewModel, initialDraft: draft, mode: .edit)
                }
            }
            .sheet(item: $selectedPartnerAnchorID) { anchor in
                PartnerPickerSheet(anchorID: anchor.id, viewModel: viewModel)
            }
            .alert("Delete item?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
                Button("Delete", role: .destructive) {
                    if let id = deleteID { viewModel.delete(id: id) }
                    deleteID = nil
                }
                Button("Cancel", role: .cancel) { deleteID = nil }
            }
        }
        .task { viewModel.onAppear() }
        .alert("Notice", isPresented: Binding(get: { viewModel.alertText != nil }, set: { if !$0 { viewModel.alertText = nil } })) {
            Button("OK", role: .cancel) { viewModel.alertText = nil }
        } message: {
            Text(viewModel.alertText ?? "")
        }
    }

    private var filterChoices: [String] {
        viewModel.rows.flatMap { row in
            row.subtitle.split(separator: "•").map { String($0).trimmingCharacters(in: .whitespaces) }
        }.reduce(into: Set<String>()) { $0.insert($1) }.sorted()
    }
}

private enum EditorMode { case create, edit }

private struct ExpenseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LedgerFeatureViewModel
    @State private var draft: ExpenseEditorDraft
    let mode: EditorMode

    @State private var addType = ""
    @State private var addAccount = ""
    @State private var addCategory = ""

    init(viewModel: LedgerFeatureViewModel, initialDraft: ExpenseEditorDraft, mode: EditorMode) {
        self.viewModel = viewModel
        _draft = State(initialValue: initialDraft)
        self.mode = mode
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.expense)
                TextField("Type", text: $draft.type)
                TextField("Account", text: $draft.account)
                TextField("Category", text: $draft.category)
                TextField("Subcategory", text: Binding(get: { draft.subcategory ?? "" }, set: { draft.subcategory = $0.isEmpty ? nil : $0 }))
                TextField("Paid To", text: $draft.paidTo)
                TextField("Amount", value: $draft.amount, format: .number)
                TextField("Effective Amount", value: $draft.effectiveAmount, format: .number)
                Picker("Effective Mode", selection: $draft.effectiveAmountMode) {
                    Text("Auto").tag(EffectiveAmountMode.auto)
                    Text("Manual").tag(EffectiveAmountMode.manual)
                }
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                TextField("Notes", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0.isEmpty ? nil : $0 }))
                TextField("Comments", text: Binding(get: { draft.comments ?? "" }, set: { draft.comments = $0.isEmpty ? nil : $0 }))

                Section("Add missing option") {
                    TextField("New type", text: $addType)
                    Button("Add type") { Task { await viewModel.addMissingOption(kind: "expenseType", value: addType); addType = "" } }
                    TextField("New account", text: $addAccount)
                    Button("Add account") { Task { await viewModel.addMissingOption(kind: "account", value: addAccount); addAccount = "" } }
                    TextField("New category", text: $addCategory)
                    Button("Add category") { Task { await viewModel.addMissingOption(kind: "category", value: addCategory); addCategory = "" } }
                }
            }
            .navigationTitle(mode == .create ? "New Expense" : "Edit Expense")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode == .create ? "Create" : "Save") {
                        if mode == .create { viewModel.createExpense(draft) } else { viewModel.updateExpense(draft) }
                        dismiss()
                    }
                    .disabled(draft.expense.isEmpty || draft.type.isEmpty || draft.account.isEmpty || draft.category.isEmpty || draft.paidTo.isEmpty || draft.amount <= 0)
                }
            }
        }
    }
}

private struct IncomingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LedgerFeatureViewModel
    @State private var draft: IncomingEditorDraft
    let mode: EditorMode

    @State private var addType = ""
    @State private var addAccount = ""

    init(viewModel: LedgerFeatureViewModel, initialDraft: IncomingEditorDraft, mode: EditorMode) {
        self.viewModel = viewModel
        _draft = State(initialValue: initialDraft)
        self.mode = mode
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.incoming)
                TextField("Paid By", text: $draft.paidBy)
                TextField("Type", text: $draft.incomeType)
                TextField("Subtype", text: Binding(get: { draft.incomeSubtype ?? "" }, set: { draft.incomeSubtype = $0.isEmpty ? nil : $0 }))
                TextField("Account", text: $draft.account)
                TextField("Amount", value: $draft.amount, format: .number)
                TextField("Effective Amount", value: $draft.effectiveAmount, format: .number)
                Picker("Effective Mode", selection: $draft.effectiveAmountMode) {
                    Text("Auto").tag(EffectiveAmountMode.auto)
                    Text("Manual").tag(EffectiveAmountMode.manual)
                }
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                TextField("Notes", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0.isEmpty ? nil : $0 }))
                TextField("Comments", text: Binding(get: { draft.comments ?? "" }, set: { draft.comments = $0.isEmpty ? nil : $0 }))

                Section("Add missing option") {
                    TextField("New income type", text: $addType)
                    Button("Add type") { Task { await viewModel.addMissingOption(kind: "incomeType", value: addType); addType = "" } }
                    TextField("New account", text: $addAccount)
                    Button("Add account") { Task { await viewModel.addMissingOption(kind: "account", value: addAccount); addAccount = "" } }
                }
            }
            .navigationTitle(mode == .create ? "New Incoming" : "Edit Incoming")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode == .create ? "Create" : "Save") {
                        if mode == .create { viewModel.createIncoming(draft) } else { viewModel.updateIncoming(draft) }
                        dismiss()
                    }
                    .disabled(draft.incoming.isEmpty || draft.paidBy.isEmpty || draft.incomeType.isEmpty || draft.account.isEmpty || draft.amount <= 0)
                }
            }
        }
    }
}

private struct BulkCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LedgerKind
    @ObservedObject var viewModel: LedgerFeatureViewModel
    @State private var input = ""

    var body: some View {
        NavigationStack {
            Form {
                Text("Format: title,amount,date(YYYY-MM-DD),field1,field2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $input)
                    .frame(minHeight: 220)
            }
            .navigationTitle("Bulk Create")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        let lines = input.split(separator: "\n").map(String.init)
                        if kind == .expense {
                            let drafts = lines.compactMap(parseExpense)
                            viewModel.bulkCreateExpenses(drafts)
                        } else {
                            let drafts = lines.compactMap(parseIncoming)
                            viewModel.bulkCreateIncomings(drafts)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func parseExpense(_ line: String) -> ExpenseEditorDraft? {
        let p = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard p.count >= 6, let amount = Double(p[1]), let date = LedgerScopeLogic.parseISODate(p[2]) else { return nil }
        return ExpenseEditorDraft(id: nil, expense: p[0], type: p[3], account: p[4], category: p[5], subcategory: nil, amount: amount, effectiveAmount: amount, effectiveAmountMode: .auto, date: date, paidTo: p.count > 6 ? p[6] : "", notes: nil, comments: nil, expenseId: UUID().uuidString, baseExpenseId: nil, baseExpenseLabel: nil, subExpenseId: nil)
    }

    private func parseIncoming(_ line: String) -> IncomingEditorDraft? {
        let p = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard p.count >= 6, let amount = Double(p[1]), let date = LedgerScopeLogic.parseISODate(p[2]) else { return nil }
        return IncomingEditorDraft(id: nil, incoming: p[0], paidBy: p[3], incomeType: p[4], incomeSubtype: nil, account: p[5], amount: amount, effectiveAmount: amount, effectiveAmountMode: .auto, date: date, notes: nil, comments: nil, incomingId: UUID().uuidString, baseIncomingId: nil, subIncomingId: nil)
    }
}

private struct PartnerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let anchorID: String
    @ObservedObject var viewModel: LedgerFeatureViewModel

    var body: some View {
        NavigationStack {
            List(viewModel.partnerCandidates(excluding: anchorID)) { row in
                Button(row.title) {
                    viewModel.addPartner(anchorID: anchorID, partnerID: row.id)
                    dismiss()
                }
            }
            .navigationTitle("Select Partner")
        }
    }
}

private struct PaybackLinksManagerView: View {
    let target: PaybackTarget
    @ObservedObject var viewModel: LedgerFeatureViewModel

    @State private var rows: [PaybackLinkViewData] = []
    @State private var candidates: [(id: String, title: String)] = []
    @State private var selectedCandidate: String = ""
    @State private var amount: String = ""
    @State private var notes: String = ""
    @State private var loading = false

    var body: some View {
        List {
            Section("Create link") {
                Picker("Counterparty", selection: $selectedCandidate) {
                    ForEach(candidates, id: \.id) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                TextField("Notes", text: $notes)
                Button("Create") {
                    guard let parsed = Double(amount), !selectedCandidate.isEmpty else { return }
                    Task {
                        try? await viewModel.createPaybackLink(target: target, otherId: selectedCandidate, amount: parsed, notes: notes.isEmpty ? nil : notes)
                        await load()
                    }
                }
            }

            Section("Links") {
                ForEach(rows) { row in
                    VStack(alignment: .leading) {
                        Text(row.counterpartyTitle)
                        Text("Allocated: \(row.allocatedAmount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let notes = row.notes, !notes.isEmpty {
                            Text(notes).font(.footnote)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task {
                                try? await viewModel.removePaybackLink(id: row.id)
                                await load()
                            }
                        } label: { Text("Delete") }
                    }
                }
            }
        }
        .overlay { if loading { ProgressView() } }
        .navigationTitle("Payback Links")
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            rows = try await viewModel.loadPaybackLinks(for: target)
            candidates = try await viewModel.paybackCandidates(for: target)
            if selectedCandidate.isEmpty { selectedCandidate = candidates.first?.id ?? "" }
        } catch {
            rows = []
            candidates = []
        }
    }
}

private struct RowID: Identifiable {
    let id: String
}
