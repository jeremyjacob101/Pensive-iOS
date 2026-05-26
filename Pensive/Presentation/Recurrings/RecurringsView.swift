import SwiftUI

private struct RowID: Identifiable {
    let id: String
}

struct RecurringsFeatureView: View {
    @StateObject private var viewModel: RecurringsFeatureViewModel
    @State private var showCreate = false
    @State private var editingID: RowID?
    @State private var deleteID: String?

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: RecurringsFeatureViewModel(api: api))
    }

    var body: some View {
        LoadStateView(state: viewModel.state, retry: { Task { await viewModel.refresh() } }) {
            List {
                Section("Expense Recurrings") {
                    if viewModel.expenseRows.isEmpty {
                        Text("No expense recurrings")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.expenseRows) { row in
                        recurringRow(row)
                    }
                }

                Section("Incoming Recurrings") {
                    if viewModel.incomingRows.isEmpty {
                        Text("No incoming recurrings")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.incomingRows) { row in
                        recurringRow(row)
                    }
                }
            }
            .refreshable { await viewModel.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showCreate) {
                RecurringEditorSheet(
                    viewModel: viewModel,
                    mode: .create,
                    initialDraft: .init(
                        id: nil,
                        status: "active",
                        kind: .expense,
                        name: "",
                        amount: 0,
                        frequency: "monthly",
                        dayOfMonth: 1,
                        recurringExpenseType: nil,
                        recurringExpenseAccount: nil,
                        recurringExpenseCategory: nil,
                        recurringExpenseSubcategory: nil,
                        recurringExpensePaidTo: nil,
                        recurringIncomingPaidBy: nil,
                        recurringIncomingType: nil,
                        recurringIncomingSubtype: nil,
                        recurringIncomingAccount: nil,
                        notes: nil
                    )
                )
            }
            .sheet(item: $editingID) { id in
                if let draft = viewModel.draft(for: id.id) {
                    RecurringEditorSheet(viewModel: viewModel, mode: .edit, initialDraft: draft)
                }
            }
            .alert("Delete recurring?", isPresented: Binding(get: { deleteID != nil }, set: { if !$0 { deleteID = nil } })) {
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
        .navigationTitle("Recurrings")
    }

    private func recurringRow(_ row: RecurringItemViewData) -> some View {
        DisclosureGroup {
            Text(row.scheduleLine).font(.footnote)
            ForEach(row.details, id: \.self) { detail in
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button("Edit") { editingID = RowID(id: row.id) }
                Button(viewModel.statusInFlightIDs.contains(row.id) ? "Updating…" : (row.status.lowercased() == "active" ? "Set inactive" : "Set active")) {
                    viewModel.toggleStatus(id: row.id, currentStatus: row.status)
                }
                .disabled(viewModel.statusInFlightIDs.contains(row.id))
                Button("Delete", role: .destructive) { deleteID = row.id }
            }
            .buttonStyle(.borderless)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(row.title).font(.headline)
                    Spacer()
                    Text(row.kind.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    Text(row.status.uppercased())
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(row.status.lowercased() == "active" ? Color.green.opacity(0.2) : Color.gray.opacity(0.2), in: Capsule())
                }
                Text(row.amountLine).font(.subheadline.weight(.medium))
                Text(row.scheduleLine).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private enum RecurringEditorMode { case create, edit }

private struct RecurringEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: RecurringsFeatureViewModel
    let mode: RecurringEditorMode
    @State private var draft: RecurringEditorDraft

    init(viewModel: RecurringsFeatureViewModel, mode: RecurringEditorMode, initialDraft: RecurringEditorDraft) {
        self.viewModel = viewModel
        self.mode = mode
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Kind", selection: $draft.kind) {
                    Text("Expense").tag(RecurringKind.expense)
                    Text("Incoming").tag(RecurringKind.incoming)
                }
                Picker("Status", selection: $draft.status) {
                    Text("Active").tag("active")
                    Text("Inactive").tag("inactive")
                }
                TextField("Name", text: $draft.name)
                TextField("Amount", value: $draft.amount, format: .number)
                TextField("Frequency", text: $draft.frequency)
                Stepper("Day of Month: \(draft.dayOfMonth)", value: $draft.dayOfMonth, in: 1 ... 31)

                if draft.kind == .expense {
                    TextField("Expense Type", text: bindingOptional(\.recurringExpenseType))
                    TextField("Expense Account", text: bindingOptional(\.recurringExpenseAccount))
                    TextField("Expense Category", text: bindingOptional(\.recurringExpenseCategory))
                    TextField("Expense Subcategory", text: bindingOptional(\.recurringExpenseSubcategory))
                    TextField("Paid To", text: bindingOptional(\.recurringExpensePaidTo))
                } else {
                    TextField("Paid By", text: bindingOptional(\.recurringIncomingPaidBy))
                    TextField("Incoming Type", text: bindingOptional(\.recurringIncomingType))
                    TextField("Incoming Subtype", text: bindingOptional(\.recurringIncomingSubtype))
                    TextField("Incoming Account", text: bindingOptional(\.recurringIncomingAccount))
                }

                TextField("Notes", text: bindingOptional(\.notes))
            }
            .navigationTitle(mode == .create ? "New Recurring" : "Edit Recurring")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(mode == .create ? "Create" : "Save") {
                        if mode == .create {
                            viewModel.create(draft)
                        } else {
                            viewModel.update(draft)
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private func bindingOptional(_ keyPath: WritableKeyPath<RecurringEditorDraft, String?>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] ?? "" }, set: { draft[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }
}
