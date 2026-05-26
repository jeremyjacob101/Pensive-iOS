import Foundation
import SwiftUI

enum RecurringKind: String, CaseIterable {
    case expense
    case incoming
}

struct RecurringItemViewData: Identifiable {
    let id: String
    let kind: RecurringKind
    let status: String
    let title: String
    let amountLine: String
    let scheduleLine: String
    let details: [String]
}

struct RecurringEditorDraft {
    var id: String?
    var status: String
    var kind: RecurringKind
    var name: String
    var amount: Double
    var frequency: String
    var dayOfMonth: Int
    var recurringExpenseType: String?
    var recurringExpenseAccount: String?
    var recurringExpenseCategory: String?
    var recurringExpenseSubcategory: String?
    var recurringExpensePaidTo: String?
    var recurringIncomingPaidBy: String?
    var recurringIncomingType: String?
    var recurringIncomingSubtype: String?
    var recurringIncomingAccount: String?
    var notes: String?
}

@MainActor
final class RecurringsFeatureViewModel: ObservableObject {
    @Published private(set) var state: ViewLoadState = .loading
    @Published private(set) var expenseRows: [RecurringItemViewData] = []
    @Published private(set) var incomingRows: [RecurringItemViewData] = []
    @Published var isSaving = false
    @Published var statusInFlightIDs: Set<String> = []
    @Published var alertText: String?

    private let api: ConvexAPI
    private let formatter: NumberFormatter
    private(set) var recurrings: [RecurringDTO] = []

    init(api: ConvexAPI) {
        self.api = api
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "ILS"
        formatter.locale = Locale(identifier: "he_IL")
        self.formatter = formatter
    }

    func onAppear() {
        if recurrings.isEmpty {
            Task { await refresh() }
        }
    }

    func refresh() async {
        if case .content = state {} else if case .empty = state {} else { state = .loading }
        do {
            recurrings = try await loadAllRecurrings()
            rebuildRows()
            // Keep screen interactive even when there are no rows so create actions remain visible.
            state = .content
        } catch {
            state = .error(message: message(for: error))
        }
    }

    func create(_ draft: RecurringEditorDraft) {
        guard validate(draft: draft) else { return }
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                _ = try await api.recurrings.create(createDTO(from: draft))
                await refresh()
            } catch {
                alertText = message(for: error)
            }
        }
    }

    func update(_ draft: RecurringEditorDraft) {
        guard validate(draft: draft), draft.id != nil else { return }
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                _ = try await api.recurrings.update(updateDTO(from: draft))
                await refresh()
            } catch {
                alertText = message(for: error)
            }
        }
    }

    func delete(id: String) {
        Task {
            do {
                _ = try await api.recurrings.remove(id: DocumentID(id))
                await refresh()
            } catch {
                alertText = message(for: error)
            }
        }
    }

    func toggleStatus(id: String, currentStatus: String) {
        guard !statusInFlightIDs.contains(id) else { return }
        let next = currentStatus.lowercased() == "active" ? "inactive" : "active"
        statusInFlightIDs.insert(id)
        Task {
            defer { statusInFlightIDs.remove(id) }
            do {
                _ = try await api.recurrings.setStatus(.init(id: id, status: next))
                await refresh()
            } catch {
                alertText = message(for: error)
            }
        }
    }

    func draft(for id: String) -> RecurringEditorDraft? {
        guard let row = recurrings.first(where: { $0._id == id }) else { return nil }
        return Self.draft(from: row)
    }

    func validate(draft: RecurringEditorDraft) -> Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { alertText = "Name is required."; return false }
        guard draft.amount > 0 else { alertText = "Amount must be greater than zero."; return false }
        guard (1 ... 31).contains(draft.dayOfMonth) else { alertText = "Day of month must be 1-31."; return false }

        if draft.kind == .expense {
            guard !(draft.recurringExpenseType ?? "").isEmpty,
                  !(draft.recurringExpenseAccount ?? "").isEmpty,
                  !(draft.recurringExpenseCategory ?? "").isEmpty,
                  !(draft.recurringExpensePaidTo ?? "").isEmpty else {
                alertText = "Expense recurring requires type, account, category, and paid to."
                return false
            }
        } else {
            guard !(draft.recurringIncomingPaidBy ?? "").isEmpty,
                  !(draft.recurringIncomingType ?? "").isEmpty,
                  !(draft.recurringIncomingAccount ?? "").isEmpty else {
                alertText = "Incoming recurring requires paid by, type, and account."
                return false
            }
        }
        return true
    }

    func createDTO(from draft: RecurringEditorDraft) -> RecurringMutationDTO {
        let normalized = Self.clearedByKind(draft)
        return .init(
            status: normalized.status,
            kind: normalized.kind.rawValue,
            name: normalized.name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: normalized.amount,
            frequency: normalized.frequency,
            dayOfMonth: normalized.dayOfMonth,
            recurringExpenseType: normalized.recurringExpenseType,
            recurringExpenseAccount: normalized.recurringExpenseAccount,
            recurringExpenseCategory: normalized.recurringExpenseCategory,
            recurringExpenseSubcategory: normalized.recurringExpenseSubcategory,
            recurringExpensePaidTo: normalized.recurringExpensePaidTo,
            recurringIncomingPaidBy: normalized.recurringIncomingPaidBy,
            recurringIncomingType: normalized.recurringIncomingType,
            recurringIncomingSubtype: normalized.recurringIncomingSubtype,
            recurringIncomingAccount: normalized.recurringIncomingAccount,
            notes: normalized.notes
        )
    }

    func updateDTO(from draft: RecurringEditorDraft) -> RecurringUpdateDTO {
        let normalized = Self.clearedByKind(draft)
        return .init(
            id: draft.id ?? "",
            status: normalized.status,
            kind: normalized.kind.rawValue,
            name: normalized.name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: normalized.amount,
            frequency: normalized.frequency,
            dayOfMonth: normalized.dayOfMonth,
            recurringExpenseType: normalized.recurringExpenseType,
            recurringExpenseAccount: normalized.recurringExpenseAccount,
            recurringExpenseCategory: normalized.recurringExpenseCategory,
            recurringExpenseSubcategory: normalized.recurringExpenseSubcategory,
            recurringExpensePaidTo: normalized.recurringExpensePaidTo,
            recurringIncomingPaidBy: normalized.recurringIncomingPaidBy,
            recurringIncomingType: normalized.recurringIncomingType,
            recurringIncomingSubtype: normalized.recurringIncomingSubtype,
            recurringIncomingAccount: normalized.recurringIncomingAccount,
            notes: normalized.notes
        )
    }

    private static func clearedByKind(_ draft: RecurringEditorDraft) -> RecurringEditorDraft {
        var normalized = draft
        if normalized.kind == .expense {
            normalized.recurringIncomingPaidBy = nil
            normalized.recurringIncomingType = nil
            normalized.recurringIncomingSubtype = nil
            normalized.recurringIncomingAccount = nil
        } else {
            normalized.recurringExpenseType = nil
            normalized.recurringExpenseAccount = nil
            normalized.recurringExpenseCategory = nil
            normalized.recurringExpenseSubcategory = nil
            normalized.recurringExpensePaidTo = nil
        }
        return normalized
    }

    private func loadAllRecurrings() async throws -> [RecurringDTO] {
        var all: [RecurringDTO] = []
        var cursor: String? = nil

        while true {
            let page = try await api.recurrings.list(.init(paginationOpts: .init(cursor: cursor, numItems: 100)))
            all.append(contentsOf: page.page)
            if page.isDone { break }
            cursor = page.continueCursor
        }

        return all
    }

    private func rebuildRows() {
        let mapped = recurrings.map { row -> RecurringItemViewData in
            let kind = RecurringKind(rawValue: row.kind?.lowercased() ?? "expense") ?? .expense
            let details = detailsForRow(row, kind: kind)
            return .init(
                id: row._id,
                kind: kind,
                status: row.status,
                title: row.name,
                amountLine: money(row.amount),
                scheduleLine: "\(row.frequency) on day \(row.dayOfMonth)",
                details: details
            )
        }.sorted(by: { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending })

        expenseRows = mapped.filter { $0.kind == .expense }
        incomingRows = mapped.filter { $0.kind == .incoming }
    }

    private func detailsForRow(_ row: RecurringDTO, kind: RecurringKind) -> [String] {
        if kind == .expense {
            return [
                "Type: \(row.recurringExpenseType ?? "")",
                "Account: \(row.recurringExpenseAccount ?? "")",
                "Category: \(row.recurringExpenseCategory ?? "")",
                "Subcategory: \(row.recurringExpenseSubcategory ?? "")",
                "Paid To: \(row.recurringExpensePaidTo ?? "")",
                "Notes: \(row.notes ?? "")"
            ]
        }
        return [
            "Paid By: \(row.recurringIncomingPaidBy ?? "")",
            "Type: \(row.recurringIncomingType ?? "")",
            "Subtype: \(row.recurringIncomingSubtype ?? "")",
            "Account: \(row.recurringIncomingAccount ?? "")",
            "Notes: \(row.notes ?? "")"
        ]
    }

    private func money(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "₪%.2f", value)
    }

    private func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .networkUnavailable: return "Network unavailable."
            case .unauthorized: return "Unauthorized."
            case .forbidden: return "Forbidden."
            case .notFound: return "Not found."
            case .server(let message): return message
            case .validation(let message): return message
            case .decoding(let message): return message
            }
        }
        return error.localizedDescription
    }

    private static func draft(from row: RecurringDTO) -> RecurringEditorDraft {
        .init(
            id: row._id,
            status: row.status,
            kind: RecurringKind(rawValue: row.kind?.lowercased() ?? "expense") ?? .expense,
            name: row.name,
            amount: row.amount,
            frequency: row.frequency,
            dayOfMonth: row.dayOfMonth,
            recurringExpenseType: row.recurringExpenseType,
            recurringExpenseAccount: row.recurringExpenseAccount,
            recurringExpenseCategory: row.recurringExpenseCategory,
            recurringExpenseSubcategory: row.recurringExpenseSubcategory,
            recurringExpensePaidTo: row.recurringExpensePaidTo,
            recurringIncomingPaidBy: row.recurringIncomingPaidBy,
            recurringIncomingType: row.recurringIncomingType,
            recurringIncomingSubtype: row.recurringIncomingSubtype,
            recurringIncomingAccount: row.recurringIncomingAccount,
            notes: row.notes
        )
    }

}
