import SwiftUI

struct NotepadNoteViewData: Identifiable {
    let id: String
    var title: String
    var content: String
}

struct NotepadTableViewData: Identifiable {
    let id: String
    var title: String
    var cells: [[String]]
}

struct NotepadWorkspaceViewData {
    var notes: [NotepadNoteViewData]
    var tables: [NotepadTableViewData]
}

enum NotepadWorkspaceNormalization {
    static func normalize(_ dto: NotepadWorkspaceDTO) -> NotepadWorkspaceViewData {
        let notes = dto.notes.map { note in
            NotepadNoteViewData(
                id: note.id.isEmpty ? UUID().uuidString : note.id,
                title: note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Note" : note.title,
                content: note.content
            )
        }

        let tables = dto.tables.map { table in
            let normalizedCells = normalizeCells(table.cells)
            return NotepadTableViewData(
                id: table.id.isEmpty ? UUID().uuidString : table.id,
                title: table.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Table" : table.title,
                cells: normalizedCells
            )
        }

        return .init(notes: notes, tables: tables)
    }

    static func normalizeCells(_ cells: [[String]]) -> [[String]] {
        if cells.isEmpty {
            return [[""]]
        }
        let width = max(1, cells.map(\.count).max() ?? 1)
        return cells.map { row in
            if row.count == width { return row }
            return row + Array(repeating: "", count: width - row.count)
        }
    }

    static func setCell(cells: [[String]], row: Int, col: Int, value: String) -> [[String]] {
        var next = normalizeCells(cells)
        guard row >= 0, col >= 0, row < next.count, col < next[row].count else { return next }
        next[row][col] = value
        return next
    }
}

@MainActor
private final class NotepadFeatureViewModel: ObservableObject {
    @Published private(set) var state: ViewLoadState = .loading
    @Published private(set) var notes: [NotepadNoteViewData] = []
    @Published private(set) var tables: [NotepadTableViewData] = []
    @Published var saveErrorText: String?

    private let api: ConvexAPI
    private var saveTasks: [String: Task<Void, Never>] = [:]

    init(api: ConvexAPI) {
        self.api = api
    }

    func onAppear() {
        if notes.isEmpty && tables.isEmpty {
            Task { await refresh() }
        }
    }

    func refresh() async {
        let shouldShowFullScreenError = !state.hasLoadedContent
        if shouldShowFullScreenError { state = .loading }
        do {
            let workspace = try await api.notepad.getMine()
            apply(workspace: workspace)
            state = .content
        } catch {
            if let workspace = debugFixtureWorkspaceIfEnabled() {
                apply(workspace: workspace)
                state = .content
            } else {
                saveErrorText = "Failed to refresh notepad."
                if shouldShowFullScreenError {
                    state = .error(message: "Failed to load notepad")
                }
            }
        }
    }

    func addNote() {
        Task {
            do {
                try await api.notepad.addNote(.init(noteId: nil, title: "Untitled Note"))
                await refresh()
            } catch {
                saveErrorText = "Failed to add note."
            }
        }
    }

    func createNote(title: String, content: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return }

        let noteID = "note-\(UUID().uuidString.lowercased())"
        Task {
            do {
                try await api.notepad.addNote(.init(noteId: noteID, title: trimmedTitle))
                try await api.notepad.saveNoteContent(.init(noteId: noteID, content: trimmedContent))
                await refresh()
            } catch {
                saveErrorText = "Failed to create note."
            }
        }
    }

    func addTable() {
        Task {
            do {
                try await api.notepad.addTable()
                await refresh()
            } catch {
                saveErrorText = "Failed to add table."
            }
        }
    }

    func cleanupEmptyNotes() {
        Task {
            do {
                try await api.notepad.cleanupEmptyNotes()
                await refresh()
            } catch {
                saveErrorText = "Cleanup failed."
            }
        }
    }

    func renameNote(id: String, title: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].title = title
        debounceSave(key: "note-title-\(id)") { [api] in
            try await api.notepad.renameNote(.init(noteId: id, title: title))
        }
    }

    func saveNoteContent(id: String, content: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].content = content
        debounceSave(key: "note-content-\(id)") { [api] in
            try await api.notepad.saveNoteContent(.init(noteId: id, content: content))
        }
    }

    func renameTable(id: String, title: String) {
        guard let index = tables.firstIndex(where: { $0.id == id }) else { return }
        tables[index].title = title
        debounceSave(key: "table-title-\(id)") { [api] in
            try await api.notepad.renameTable(.init(tableId: id, title: title))
        }
    }

    func deleteTable(id: String) {
        Task {
            do {
                try await api.notepad.deleteTable(.init(tableId: id))
                await refresh()
            } catch {
                saveErrorText = "Failed to delete table."
            }
        }
    }

    func editCell(tableID: String, row: Int, col: Int, value: String) {
        guard let index = tables.firstIndex(where: { $0.id == tableID }) else { return }
        tables[index].cells = NotepadWorkspaceNormalization.setCell(cells: tables[index].cells, row: row, col: col, value: value)
        debounceSave(key: "cell-\(tableID)-\(row)-\(col)") { [api] in
            try await api.notepad.saveCell(.init(tableId: tableID, rowIndex: row, colIndex: col, value: value))
        }
    }

    func addRow(tableID: String) {
        Task {
            do {
                try await api.notepad.addRow(.init(tableId: tableID))
                await refresh()
            } catch {
                saveErrorText = "Failed to add row."
            }
        }
    }

    func addColumn(tableID: String) {
        Task {
            do {
                try await api.notepad.addColumn(.init(tableId: tableID))
                await refresh()
            } catch {
                saveErrorText = "Failed to add column."
            }
        }
    }

    func removeLastRow(tableID: String) {
        Task {
            do {
                try await api.notepad.removeLastRow(.init(tableId: tableID))
                await refresh()
            } catch {
                saveErrorText = "Failed to remove row."
            }
        }
    }

    func removeLastColumn(tableID: String) {
        Task {
            do {
                try await api.notepad.removeLastColumn(.init(tableId: tableID))
                await refresh()
            } catch {
                saveErrorText = "Failed to remove column."
            }
        }
    }

    private func apply(workspace: NotepadWorkspaceDTO) {
        let normalized = NotepadWorkspaceNormalization.normalize(workspace)
        notes = normalized.notes
        tables = normalized.tables
    }

    private func debounceSave(key: String, delayNs: UInt64 = 400_000_000, _ operation: @escaping @Sendable () async throws -> Void) {
        saveTasks[key]?.cancel()
        saveTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            do {
                try await operation()
                await MainActor.run { self?.saveErrorText = nil }
            } catch {
                await MainActor.run { self?.saveErrorText = "Autosave failed. It will retry on your next edit." }
            }
        }
    }

    private func debugFixtureWorkspaceIfEnabled() -> NotepadWorkspaceDTO? {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["UI_TEST_NOTEPAD_FIXTURE"] == "1" else { return nil }
        return Self.fixtureWorkspace()
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static func fixtureWorkspace() -> NotepadWorkspaceDTO {
        .init(
            _id: nil,
            _creationTime: nil,
            userId: "ui-test",
            notes: [.init(id: "note-1", title: "Today", content: "Initial note content")],
            tables: [.init(id: "table-1", title: "Budget", cells: [["Category", "Amount"], ["Rent", "6000"]])],
            updatedAt: 0
        )
    }
    #endif
}

private struct NotepadFeatureView: View {
    enum Panel: String, CaseIterable {
        case notes = "Notes"
        case tables = "Tables"
    }

    @StateObject private var viewModel: NotepadFeatureViewModel
    @State private var panel: Panel = .notes
    @State private var showingNewNoteSheet = false
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var editingNoteID: String?
    @State private var editingTableID: String?

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: NotepadFeatureViewModel(api: api))
    }

    var body: some View {
        LoadStateView(state: viewModel.state, retry: { Task { await viewModel.refresh() } }) {
            NotepadWorkspaceListView(
                panel: $panel,
                saveErrorText: viewModel.saveErrorText,
                notes: viewModel.notes,
                tables: viewModel.tables,
                onNoteTap: { editingNoteID = $0.id },
                onTableTap: { editingTableID = $0.id }
            )
            .listStyle(.insetGrouped)
            .navigationTitle("Notepad")
            .toolbar {
                addToolbar
            }
            .refreshable { await viewModel.refresh() }
            .sheet(isPresented: $showingNewNoteSheet) {
                newNoteSheet
            }
            .sheet(item: editingNoteBinding) { editorID in
                noteEditorSheet(editorID)
            }
            .sheet(item: editingTableBinding) { editorID in
                tableEditorSheet(editorID)
            }
        }
        .task { viewModel.onAppear() }
    }

    @ToolbarContentBuilder
    private var addToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("New Note") {
                    newNoteTitle = ""
                    newNoteContent = ""
                    showingNewNoteSheet = true
                }
                .accessibilityIdentifier("notepad_add_note")
                Button("New Table") { viewModel.addTable() }
                    .accessibilityIdentifier("notepad_add_table")
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private var editingNoteBinding: Binding<NotepadEditorID?> {
        Binding(
            get: {
                guard let id = editingNoteID else { return nil }
                return NotepadEditorID(rawValue: id)
            },
            set: { editingNoteID = $0?.rawValue }
        )
    }

    private var editingTableBinding: Binding<NotepadEditorID?> {
        Binding(
            get: {
                guard let id = editingTableID else { return nil }
                return NotepadEditorID(rawValue: id)
            },
            set: { editingTableID = $0?.rawValue }
        )
    }

    private var canSaveNewNote: Bool {
        !newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var newNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Note title", text: $newNoteTitle)
                }
                Section("Content") {
                    TextEditor(text: $newNoteContent)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingNewNoteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.createNote(title: newNoteTitle, content: newNoteContent)
                        showingNewNoteSheet = false
                    }
                    .disabled(!canSaveNewNote)
                }
            }
        }
    }

    @ViewBuilder
    private func noteEditorSheet(_ editorID: NotepadEditorID) -> some View {
        if let note = viewModel.notes.first(where: { $0.id == editorID.rawValue }) {
            NavigationStack {
                Form {
                    Section("Title") {
                        TextField("Title", text: Binding(
                            get: { note.title },
                            set: { viewModel.renameNote(id: note.id, title: $0) }
                        ))
                        .accessibilityIdentifier("notepad_note_title_\(note.id)")
                    }
                    Section("Content") {
                        TextEditor(text: Binding(
                            get: { note.content },
                            set: { viewModel.saveNoteContent(id: note.id, content: $0) }
                        ))
                        .frame(minHeight: 260)
                        .accessibilityIdentifier("notepad_note_content_\(note.id)")
                    }
                }
                .navigationTitle("Edit Note")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { editingNoteID = nil }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tableEditorSheet(_ editorID: NotepadEditorID) -> some View {
        if let table = viewModel.tables.first(where: { $0.id == editorID.rawValue }) {
            NavigationStack {
                List {
                    Section {
                        TextField("Table Title", text: Binding(
                            get: { table.title },
                            set: { viewModel.renameTable(id: table.id, title: $0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("notepad_table_title_\(table.id)")
                    }
                    Section {
                        NotepadEditableTableGrid(
                            table: table,
                            onEditCell: { row, col, value in
                                viewModel.editCell(tableID: table.id, row: row, col: col, value: value)
                            },
                            onAddRow: { viewModel.addRow(tableID: table.id) },
                            onRemoveRow: { viewModel.removeLastRow(tableID: table.id) },
                            onAddColumn: { viewModel.addColumn(tableID: table.id) },
                            onRemoveColumn: { viewModel.removeLastColumn(tableID: table.id) }
                        )
                        .accessibilityIdentifier("notepad_table_actions_\(table.id)")
                    }
                    Section {
                        Button("Delete Table", role: .destructive) {
                            viewModel.deleteTable(id: table.id)
                            editingTableID = nil
                        }
                    }
                }
                .navigationTitle("Edit Table")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { editingTableID = nil }
                    }
                }
            }
        }
    }
}

private struct NotepadEditorID: Identifiable {
    let rawValue: String
    var id: String { rawValue }
}

private struct NotepadEditableTableGrid: View {
    let table: NotepadTableViewData
    let onEditCell: (Int, Int, String) -> Void
    let onAddRow: () -> Void
    let onRemoveRow: () -> Void
    let onAddColumn: () -> Void
    let onRemoveColumn: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(table.cells.enumerated()), id: \.offset) { rowIndex, row in
                            NotepadEditableTableRow(
                                tableID: table.id,
                                rowIndex: rowIndex,
                                row: row,
                                onEditCell: onEditCell
                            )
                        }
                    }

                    HStack(spacing: 8) {
                        tableControlButton(systemName: "minus", action: onRemoveRow)
                        tableControlButton(systemName: "plus", action: onAddRow)
                    }
                }
            }

            VStack(spacing: 8) {
                tableControlButton(systemName: "plus", action: onAddColumn)
                tableControlButton(systemName: "minus", action: onRemoveColumn)
            }
            .padding(.top, 2)
        }
    }

    private func tableControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.bordered)
    }
}

private struct NotepadEditableTableRow: View {
    let tableID: String
    let rowIndex: Int
    let row: [String]
    let onEditCell: (Int, Int, String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                TextField("Cell", text: Binding(
                    get: { cell },
                    set: { onEditCell(rowIndex, colIndex, $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 130)
                .accessibilityIdentifier("notepad_cell_\(tableID)_\(rowIndex)_\(colIndex)")
            }
        }
    }
}

private struct NotepadWorkspaceListView: View {
    @Binding var panel: NotepadFeatureView.Panel
    let saveErrorText: String?
    let notes: [NotepadNoteViewData]
    let tables: [NotepadTableViewData]
    let onNoteTap: (NotepadNoteViewData) -> Void
    let onTableTap: (NotepadTableViewData) -> Void

    var body: some View {
        List {
            NotepadPanelPickerSection(panel: $panel)
            NotepadSaveErrorSection(message: saveErrorText)
            NotepadPanelRowsView(
                panel: panel,
                notes: notes,
                tables: tables,
                onNoteTap: onNoteTap,
                onTableTap: onTableTap
            )
        }
    }
}

private struct NotepadPanelPickerSection: View {
    @Binding var panel: NotepadFeatureView.Panel

    var body: some View {
        Section {
            Picker("Panel", selection: $panel) {
                Text(NotepadFeatureView.Panel.notes.rawValue).tag(NotepadFeatureView.Panel.notes)
                Text(NotepadFeatureView.Panel.tables.rawValue).tag(NotepadFeatureView.Panel.tables)
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct NotepadSaveErrorSection: View {
    let message: String?

    var body: some View {
        if let message {
            Section {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct NotepadPanelRowsView: View {
    let panel: NotepadFeatureView.Panel
    let notes: [NotepadNoteViewData]
    let tables: [NotepadTableViewData]
    let onNoteTap: (NotepadNoteViewData) -> Void
    let onTableTap: (NotepadTableViewData) -> Void

    var body: some View {
        switch panel {
        case .notes:
            NotepadNotesListView(notes: notes, onTap: onNoteTap)
        case .tables:
            NotepadTablesListView(tables: tables, onTap: onTableTap)
        }
    }
}

private struct NotepadNotesListView: View {
    let notes: [NotepadNoteViewData]
    let onTap: (NotepadNoteViewData) -> Void

    var body: some View {
        ForEach(notes, id: \.id) { note in
            Button {
                onTap(note)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(note.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }
}

private struct NotepadTablesListView: View {
    let tables: [NotepadTableViewData]
    let onTap: (NotepadTableViewData) -> Void

    var body: some View {
        ForEach(tables, id: \.id) { table in
            Button {
                onTap(table)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(table.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    NotepadTablePreview(cells: table.cells)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
    }
}

private struct NotepadTablePreview: View {
    let cells: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, row in
                    NotepadTablePreviewRow(cells: row)
                }
            }
        }
    }
}

private struct NotepadTablePreviewRow: View {
    let cells: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                NotepadTablePreviewCell(text: cell)
            }
        }
    }
}

private struct NotepadTablePreviewCell: View {
    let text: String

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.caption)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .frame(width: 120, height: 32, alignment: .leading)
            .padding(.horizontal, 8)
            .overlay(
                Rectangle()
                    .stroke(.secondary.opacity(0.35), lineWidth: 0.5)
            )
    }
}

enum TrackingTimelineSegmentState: String {
    case paid
    case unpaid
    case buffer
    case empty
}

struct TrackingTimelineSegment: Identifiable {
    let id: String
    let month: String
    let state: TrackingTimelineSegmentState
}

private struct TrackingTimelineRowViewData: Identifiable {
    let id: String
    let key: String
    let source: String
    let label: String
    let colorHex: String
    let paidMonths: Set<String>
    let currentMonth: String
    let availableMonths: [String]
    var startMonth: String
    var trailingBufferMonths: Int
    var segments: [TrackingTimelineSegment]
}

enum TrackingTimelineLogic {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static func monthDate(_ month: String) -> Date? {
        let comps = month.split(separator: "-")
        guard comps.count == 2, let y = Int(comps[0]), let m = Int(comps[1]), (1 ... 12).contains(m) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: 1))
    }

    static func monthString(_ date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        return String(format: "%04d-%02d", y, m)
    }

    static func monthRange(start: String, end: String) -> [String] {
        guard let startDate = monthDate(start), let endDate = monthDate(end), startDate <= endDate else { return [] }
        var result: [String] = []
        var cursor = startDate
        while cursor <= endDate {
            result.append(monthString(cursor))
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? cursor
            if result.count > 2400 { break }
        }
        return result
    }

    static func segments(months: [String], paidMonths: Set<String>, currentMonth: String, trailingBufferMonths: Int) -> [TrackingTimelineSegment] {
        guard let current = monthDate(currentMonth) else {
            return months.map { .init(id: $0, month: $0, state: paidMonths.contains($0) ? .paid : .unpaid) }
        }

        let recentUnpaidBufferMonths: Set<String> = {
            let eligible = months.compactMap { month -> (String, Date)? in
                guard !paidMonths.contains(month), let date = monthDate(month), date <= current else { return nil }
                return (month, date)
            }
            let sorted = eligible.sorted { $0.1 > $1.1 }
            return Set(sorted.prefix(max(0, trailingBufferMonths)).map(\.0))
        }()

        return months.map { month in
            let state: TrackingTimelineSegmentState
            if paidMonths.contains(month) {
                state = .paid
            } else if let monthDate = monthDate(month) {
                if monthDate > current {
                    state = .empty
                } else if recentUnpaidBufferMonths.contains(month) {
                    state = .buffer
                } else {
                    state = .unpaid
                }
            } else {
                state = .empty
            }
            return .init(id: month, month: month, state: state)
        }
    }
}

struct TrackingTimelineRowPersistenceStore {
    private let defaults: UserDefaults
    private let startPrefix = "tracking.timeline.start"
    private let bufferPrefix = "tracking.timeline.buffer"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func startMonth(source: String, key: String) -> String? {
        defaults.string(forKey: "\(startPrefix).\(source).\(key)")
    }

    func trailingBufferMonths(source: String, key: String) -> Int? {
        let value = defaults.object(forKey: "\(bufferPrefix).\(source).\(key)") as? Int
        return value
    }

    func setStartMonth(_ value: String, source: String, key: String) {
        defaults.set(value, forKey: "\(startPrefix).\(source).\(key)")
    }

    func setTrailingBufferMonths(_ value: Int, source: String, key: String) {
        defaults.set(max(0, value), forKey: "\(bufferPrefix).\(source).\(key)")
    }
}

@MainActor
private final class TrackingFeatureViewModel: ObservableObject {
    @Published private(set) var state: ViewLoadState = .loading
    @Published private(set) var expenseRows: [TrackingTimelineRowViewData] = []
    @Published private(set) var incomingRows: [TrackingTimelineRowViewData] = []

    private let api: ConvexAPI
    private let persistence: TrackingTimelineRowPersistenceStore

    init(api: ConvexAPI, persistence: TrackingTimelineRowPersistenceStore = .init()) {
        self.api = api
        self.persistence = persistence
    }

    func onAppear() {
        if expenseRows.isEmpty && incomingRows.isEmpty {
            Task { await refresh() }
        }
    }

    func refresh() async {
        let shouldShowFullScreenError = !state.hasLoadedContent
        if shouldShowFullScreenError { state = .loading }
        do {
            let tracking = try await api.tracking.list()
            apply(response: tracking)
            state = .content
        } catch {
            if let tracking = debugFixtureResponseIfEnabled() {
                apply(response: tracking)
                state = .content
            } else {
                if shouldShowFullScreenError {
                    state = .error(message: "Failed to load tracking")
                }
            }
        }
    }

    func setStartMonth(rowID: String, source: String, key: String, month: String) {
        persistence.setStartMonth(month, source: source, key: key)
        mutateRow(id: rowID, source: source) { row in
            row.startMonth = month
            row.segments = TrackingTimelineLogic.segments(
                months: row.availableMonths,
                paidMonths: row.paidMonths,
                currentMonth: row.currentMonth,
                trailingBufferMonths: row.trailingBufferMonths
            )
        }
    }

    func setTrailingBufferMonths(rowID: String, source: String, key: String, months: Int) {
        persistence.setTrailingBufferMonths(months, source: source, key: key)
        mutateRow(id: rowID, source: source) { row in
            row.trailingBufferMonths = max(0, months)
            row.segments = TrackingTimelineLogic.segments(
                months: row.availableMonths,
                paidMonths: row.paidMonths,
                currentMonth: row.currentMonth,
                trailingBufferMonths: row.trailingBufferMonths
            )
        }
    }

    private func apply(response: TrackingResponse) {
        let rows = response.rows.map { dto -> TrackingTimelineRowViewData in
            let source = dto.source.lowercased()
            let persistedStart = persistence.startMonth(source: source, key: dto.key)
            let fallbackStart = dto.rangeMonths.first ?? response.currentMonth
            let start = persistedStart.flatMap { s in dto.rangeMonths.contains(s) ? s : nil } ?? fallbackStart
            let persistedBuffer = persistence.trailingBufferMonths(source: source, key: dto.key) ?? 0
            let months = dto.rangeMonths.isEmpty ? [response.currentMonth] : dto.rangeMonths
            let allMonths = months.last == response.currentMonth ? months : months + [response.currentMonth]
            let clipped = allMonths.filter { month in
                guard let monthDate = TrackingTimelineLogic.monthDate(month), let startDate = TrackingTimelineLogic.monthDate(start) else { return false }
                return monthDate >= startDate
            }
            let segments = TrackingTimelineLogic.segments(
                months: clipped,
                paidMonths: Set(dto.paidMonths),
                currentMonth: response.currentMonth,
                trailingBufferMonths: persistedBuffer
            )
            return .init(
                id: "\(source):\(dto.key)",
                key: dto.key,
                source: source,
                label: dto.label,
                colorHex: dto.color,
                paidMonths: Set(dto.paidMonths),
                currentMonth: response.currentMonth,
                availableMonths: clipped,
                startMonth: start,
                trailingBufferMonths: persistedBuffer,
                segments: segments
            )
        }

        expenseRows = rows.filter { $0.source == "expense" }
        incomingRows = rows.filter { $0.source == "incoming" }
    }

    private func mutateRow(id: String, source: String, _ mutate: (inout TrackingTimelineRowViewData) -> Void) {
        if source == "expense" {
            guard let index = expenseRows.firstIndex(where: { $0.id == id }) else { return }
            var row = expenseRows[index]
            mutate(&row)
            expenseRows[index] = row
        } else {
            guard let index = incomingRows.firstIndex(where: { $0.id == id }) else { return }
            var row = incomingRows[index]
            mutate(&row)
            incomingRows[index] = row
        }
    }

    private func debugFixtureResponseIfEnabled() -> TrackingResponse? {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["UI_TEST_TRACKING_FIXTURE"] == "1" else { return nil }
        return Self.fixtureResponse()
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static func fixtureResponse() -> TrackingResponse {
        .init(
            currentMonth: "2026-05",
            rows: [
                .init(key: "housing", source: "expense", kind: "category", value: "housing", parentValue: nil, color: "#FF5A5F", label: "Housing", paidMonths: ["2026-01", "2026-02", "2026-04"], rangeMonths: ["2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06"], statusByMonth: [:]),
                .init(key: "salary", source: "incoming", kind: "type", value: "salary", parentValue: nil, color: "#00A699", label: "Salary", paidMonths: ["2026-01", "2026-02", "2026-03", "2026-04", "2026-05"], rangeMonths: ["2026-01", "2026-02", "2026-03", "2026-04", "2026-05", "2026-06"], statusByMonth: [:])
            ]
        )
    }
    #endif
}

private struct TrackingFeatureView: View {
    @StateObject private var viewModel: TrackingFeatureViewModel
    @State private var expandedRowIDs: Set<String> = []

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: TrackingFeatureViewModel(api: api))
    }

    var body: some View {
        LoadStateView(state: viewModel.state, retry: { Task { await viewModel.refresh() } }) {
            List {
                if !viewModel.expenseRows.isEmpty {
                    Section("Expenses") {
                        ForEach(viewModel.expenseRows) { row in
                            TrackingTimelineRowCard(row: row, isExpanded: expandedRowIDs.contains(row.id), onToggleExpanded: {
                                toggleExpanded(row.id)
                            }, onStartMonth: { month in
                                viewModel.setStartMonth(rowID: row.id, source: row.source, key: row.key, month: month)
                            }, onBuffer: { buffer in
                                viewModel.setTrailingBufferMonths(rowID: row.id, source: row.source, key: row.key, months: buffer)
                            })
                        }
                    }
                }
                if !viewModel.incomingRows.isEmpty {
                    Section("Incomings") {
                        ForEach(viewModel.incomingRows) { row in
                            TrackingTimelineRowCard(row: row, isExpanded: expandedRowIDs.contains(row.id), onToggleExpanded: {
                                toggleExpanded(row.id)
                            }, onStartMonth: { month in
                                viewModel.setStartMonth(rowID: row.id, source: row.source, key: row.key, month: month)
                            }, onBuffer: { buffer in
                                viewModel.setTrailingBufferMonths(rowID: row.id, source: row.source, key: row.key, months: buffer)
                            })
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tracking")
            .refreshable { await viewModel.refresh() }
        }
        .task { viewModel.onAppear() }
    }

    private func toggleExpanded(_ id: String) {
        if expandedRowIDs.contains(id) {
            expandedRowIDs.remove(id)
        } else {
            expandedRowIDs.insert(id)
        }
    }
}

private struct TrackingTimelineRowCard: View {
    let row: TrackingTimelineRowViewData
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onStartMonth: (String) -> Void
    let onBuffer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(row.label)
                    .font(.headline)
                    .accessibilityIdentifier("tracking_row_title_\(row.key)")
                Spacer()
                Button(action: onToggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            TrackingPipelinePreview(segments: row.segments)
            if isExpanded {
                HStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Text("Start")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Menu {
                            ForEach(row.availableMonths, id: \.self) { month in
                                Button(month) { onStartMonth(month) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(row.startMonth)
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        }
                        .accessibilityIdentifier("tracking_start_month_\(row.key)")
                    }

                    HStack(spacing: 8) {
                        Text("Buffer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Menu {
                            ForEach(0 ... 24, id: \.self) { value in
                                Button("\(value)") { onBuffer(value) }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(row.trailingBufferMonths)")
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        }
                        .accessibilityIdentifier("tracking_buffer_\(row.key)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct TrackingPipelinePreview: View {
    let segments: [TrackingTimelineSegment]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(segments) { segment in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color(for: segment.state))
                                .frame(width: 40, height: 8)
                            Text(monthAbbrev(segment.month))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .id(segment.id)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(segment.month), \(segment.state.rawValue)")
                    }
                }
            }
            .frame(width: 276, alignment: .trailing)
            .onAppear {
                if let newest = segments.last?.id {
                    proxy.scrollTo(newest, anchor: .trailing)
                }
            }
        }
    }

    private func monthAbbrev(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), (1 ... 12).contains(m) else { return month }
        let labels = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return labels[m - 1]
    }

    private func color(for state: TrackingTimelineSegmentState) -> Color {
        switch state {
        case .paid: return .green
        case .unpaid: return .orange
        case .buffer: return Color(uiColor: .systemGray3)
        case .empty: return Color(uiColor: .systemGray4)
        }
    }
}

private enum OptionsKind: String, CaseIterable, Identifiable {
    case expenseType
    case account
    case category
    case subcategory
    case incomeType
    case incomeSubtype

    var id: String { rawValue }
    var title: String { rawValue }
    var supportsParent: Bool { self == .subcategory || self == .incomeSubtype }

    var parentKind: OptionsKind? {
        switch self {
        case .subcategory: return .category
        case .incomeSubtype: return .incomeType
        default: return nil
        }
    }
}

@MainActor
private final class OptionsViewModel: ObservableObject {
    @Published private(set) var state: ViewLoadState = .loading
    @Published private(set) var optionsByKind: [OptionsKind: [UserOptionRow]] = [:]
    @Published var selectedKind: OptionsKind = .expenseType
    @Published var inlineError: String?
    @Published var successText: String?
    @Published private(set) var trackingMismatchCount: Int = 0

    private let api: ConvexAPI
    private var trackedKeysFromTrackingRows: Set<String> = []

    init(api: ConvexAPI) {
        self.api = api
    }

    func onAppear() {
        if optionsByKind.isEmpty {
            Task { await refresh() }
        }
    }

    func refresh() async {
        let shouldShowFullScreenError = !state.hasLoadedContent
        if shouldShowFullScreenError { state = .loading }
        do {
            async let optionsListRequest = api.userOptions.list()
            async let trackingListRequest = api.tracking.list()
            let list = try await optionsListRequest
            let tracking = try await trackingListRequest
            optionsByKind = [
                .expenseType: list.expenseType,
                .account: list.account,
                .category: list.category,
                .subcategory: list.subcategory,
                .incomeType: list.incomeType,
                .incomeSubtype: list.incomeSubtype
            ]
            trackedKeysFromTrackingRows = Set(tracking.rows.map { trackingKey(kind: $0.kind, value: $0.value, parentValue: $0.parentValue) })
            trackingMismatchCount = countTrackingMismatches()
            state = .content
        } catch {
            if shouldShowFullScreenError {
                state = .error(message: "Failed to load options")
            }
        }
    }

    var parentChoices: [String] {
        guard let parentKind = selectedKind.parentKind else { return [] }
        return (optionsByKind[parentKind] ?? []).map(\.value).sorted()
    }

    func parentChoicesExcluding(_ parentValue: String?) -> [String] {
        guard let parentValue = normalized(parentValue), !parentValue.isEmpty else {
            return parentChoices
        }
        return parentChoices.filter { $0 != parentValue }
    }

    func moveToSubtypeTargets(excluding sourceValue: String) -> [String] {
        let values = (optionsByKind[selectedKind] ?? []).map(\.value)
        return values.filter { $0 != sourceValue }.sorted()
    }

    var showsMoveHint: Bool {
        switch selectedKind {
        case .category, .incomeType, .subcategory, .incomeSubtype:
            return true
        default:
            return false
        }
    }

    var supportsTrackingForSelectedKind: Bool {
        switch selectedKind {
        case .category, .subcategory, .incomeType, .incomeSubtype:
            return true
        default:
            return false
        }
    }

    var rows: [OptionsDisplayRow] {
        (optionsByKind[selectedKind] ?? []).sorted { lhs, rhs in
            if lhs.parentValue == rhs.parentValue {
                return lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
            }
            return (lhs.parentValue ?? "") < (rhs.parentValue ?? "")
        }.map { row in
            let key = trackingKey(kind: selectedKind.rawValue, value: row.value, parentValue: row.parentValue)
            let effectiveIsTracking = row.isTracking || trackedKeysFromTrackingRows.contains(key)
            return OptionsDisplayRow(
                value: row.value,
                color: row.color,
                isDefault: row.isDefault,
                isTracking: effectiveIsTracking,
                parentValue: row.parentValue
            )
        }
    }

    func add(kind: OptionsKind, value: String, parentValue: String?) async {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            inlineError = "Option name cannot be empty."
            return
        }

        if kind.supportsParent, (parentValue ?? "").isEmpty {
            inlineError = "Please select a parent."
            return
        }

        do {
            try await api.userOptions.add(.init(kind: kind.rawValue, value: trimmed, parentValue: normalized(parentValue)))
            await refresh()
            successText = "Added \(trimmed)."
            inlineError = nil
        } catch {
            inlineError = "Failed to add option."
        }
    }

    func rename(kind: OptionsKind, value: String, nextValue: String, parentValue: String?) async {
        let trimmed = nextValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            inlineError = "New name cannot be empty."
            return
        }
        do {
            try await api.userOptions.rename(.init(kind: kind.rawValue, value: value, nextValue: trimmed, parentValue: normalized(parentValue)))
            await refresh()
            successText = "Renamed successfully."
            inlineError = nil
        } catch {
            inlineError = "Failed to rename option."
        }
    }

    func updateColor(kind: OptionsKind, value: String, color: String, parentValue: String?) async {
        let normalizedColor = sanitizeHexColor(color)
        guard normalizedColor != nil else {
            inlineError = "Color must be a valid 6-digit hex value."
            return
        }
        do {
            try await api.userOptions.updateColor(.init(kind: kind.rawValue, value: value, color: normalizedColor!, parentValue: normalized(parentValue)))
            await refresh()
            inlineError = nil
        } catch {
            inlineError = "Failed to update color."
        }
    }

    func setDefault(kind: OptionsKind, value: String, isDefault: Bool, parentValue: String?) async {
        do {
            try await api.userOptions.setDefault(.init(kind: kind.rawValue, value: value, isDefault: isDefault, parentValue: normalized(parentValue)))
            await refresh()
            inlineError = nil
        } catch {
            inlineError = "Failed to set default."
        }
    }

    func setTracking(kind: OptionsKind, value: String, isTracking: Bool, parentValue: String?) async {
        do {
            try await api.userOptions.setTracking(.init(kind: kind.rawValue, value: value, isTracking: isTracking, parentValue: normalized(parentValue)))
            await refresh()
            inlineError = nil
        } catch {
            inlineError = "Failed to set tracking."
        }
    }

    func remove(kind: OptionsKind, value: String, parentValue: String?) async {
        do {
            try await api.userOptions.remove(.init(kind: kind.rawValue, value: value, parentValue: normalized(parentValue)))
            await refresh()
            inlineError = nil
        } catch {
            inlineError = "Failed to delete option."
        }
    }

    func moveToSubtype(kind: OptionsKind, sourceValue: String, targetValue: String) async {
        do {
            let request = try OptionsMutationLogic.buildMoveToSubtype(kind: kind.rawValue, sourceValue: sourceValue, targetValue: targetValue)
            try await api.userOptions.moveToSubtype(request)
            await refresh()
            inlineError = nil
        } catch {
            inlineError = message(for: error, fallback: "Failed to move to subtype.")
        }
    }

    func moveSubtype(kind: OptionsKind, value: String, sourceParentValue: String, targetParentValue: String) async {
        do {
            let request = try OptionsMutationLogic.buildMoveSubtype(
                kind: kind.rawValue,
                value: value,
                sourceParentValue: sourceParentValue,
                targetParentValue: targetParentValue
            )
            try await api.userOptions.moveSubtype(request)
            await refresh()
            inlineError = nil
        } catch {
            inlineError = message(for: error, fallback: "Failed to move subtype.")
        }
    }

    func promoteSubtype(kind: OptionsKind, value: String, parentValue: String) async {
        do {
            let request = try OptionsMutationLogic.buildPromoteSubtype(kind: kind.rawValue, value: value, parentValue: parentValue)
            try await api.userOptions.promoteSubtype(request)
            await refresh()
            inlineError = nil
        } catch {
            inlineError = message(for: error, fallback: "Failed to promote subtype.")
        }
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sanitizeHexColor(_ color: String) -> String? {
        let clean = color.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: "#", with: "")
        guard clean.range(of: #"^[0-9A-F]{6}$"#, options: .regularExpression) != nil else { return nil }
        return "#\(clean)"
    }

    private func trackingKey(kind: String, value: String, parentValue: String?) -> String {
        let parent = normalized(parentValue) ?? ""
        return "\(kind)|\(value)|\(parent)"
    }

    private func countTrackingMismatches() -> Int {
        let candidateKinds: [OptionsKind] = [.category, .subcategory, .incomeType, .incomeSubtype]
        var count = 0
        for kind in candidateKinds {
            for row in optionsByKind[kind] ?? [] {
                let key = trackingKey(kind: kind.rawValue, value: row.value, parentValue: row.parentValue)
                let inTrackingRows = trackedKeysFromTrackingRows.contains(key)
                if inTrackingRows && row.isTracking == false {
                    count += 1
                }
            }
        }
        return count
    }

    private func message(for error: Error, fallback: String) -> String {
        if let apiError = error as? APIError, case let .validation(message) = apiError {
            return message
        }
        return fallback
    }
}

private struct OptionsDisplayRow: Identifiable {
    let value: String
    let color: String
    let isDefault: Bool
    let isTracking: Bool
    let parentValue: String?
    var id: String { "\(value)|\(parentValue ?? "")" }
}

private struct OptionsFeatureView: View {
    @StateObject private var viewModel: OptionsViewModel
    @State private var addValue = ""
    @State private var addParent = ""
    @State private var renameByRow: [String: String] = [:]
    @State private var colorByRow: [String: String] = [:]
    @State private var rowPendingDelete: OptionsDisplayRow?
    @State private var moveToSubtypeContext: OptionsDisplayRow?
    @State private var moveSubtypeContext: OptionsDisplayRow?
    @State private var promoteSubtypeContext: OptionsDisplayRow?
    @State private var moveTarget = ""
    @State private var moveSubtypeTargetParent = ""

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: OptionsViewModel(api: api))
    }

    var body: some View {
        LoadStateView(state: viewModel.state, retry: { Task { await viewModel.refresh() } }) {
            List {
                Section("Kind") {
                    Picker("Kind", selection: $viewModel.selectedKind) {
                        ForEach(OptionsKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Add Option") {
                    TextField("Value", text: $addValue)
                    if viewModel.selectedKind.supportsParent {
                        Picker("Parent", selection: $addParent) {
                            Text("Select Parent").tag("")
                            ForEach(viewModel.parentChoices, id: \.self) { parent in
                                Text(parent).tag(parent)
                            }
                        }
                    }
                    Button("Add") {
                        Task { await viewModel.add(kind: viewModel.selectedKind, value: addValue, parentValue: addParent) }
                    }
                }

                Section("Options") {
                    ForEach(viewModel.rows, id: \.selfKey) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            let rowKey = row.selfKey
                            HStack {
                                Text(row.value).font(.headline)
                                Spacer()
                                Circle().fill(color(from: row.color) ?? .gray).frame(width: 14, height: 14)
                            }
                            if let parent = row.parentValue, !parent.isEmpty {
                                Text("Parent: \(parent)").font(.footnote).foregroundStyle(.secondary)
                            }
                            HStack {
                                Toggle("Default", isOn: Binding(get: { row.isDefault }, set: { next in
                                    Task { await viewModel.setDefault(kind: viewModel.selectedKind, value: row.value, isDefault: next, parentValue: row.parentValue) }
                                }))
                                if viewModel.supportsTrackingForSelectedKind {
                                    Toggle("Tracking", isOn: Binding(get: { row.isTracking }, set: { next in
                                        Task { await viewModel.setTracking(kind: viewModel.selectedKind, value: row.value, isTracking: next, parentValue: row.parentValue) }
                                    }))
                                }
                            }
                            .font(.footnote)

                            TextField("Rename", text: Binding(get: { renameByRow[rowKey, default: row.value] }, set: { renameByRow[rowKey] = $0 }))
                            Button("Apply Rename") {
                                Task {
                                    await viewModel.rename(
                                        kind: viewModel.selectedKind,
                                        value: row.value,
                                        nextValue: renameByRow[rowKey, default: row.value],
                                        parentValue: row.parentValue
                                    )
                                }
                            }
                            .buttonStyle(.bordered)

                            TextField("Hex Color #RRGGBB", text: Binding(get: { colorByRow[rowKey, default: row.color] }, set: { colorByRow[rowKey] = $0 }))
                            Button("Update Color") {
                                Task {
                                    await viewModel.updateColor(
                                        kind: viewModel.selectedKind,
                                        value: row.value,
                                        color: colorByRow[rowKey, default: row.color],
                                        parentValue: row.parentValue
                                    )
                                }
                            }
                            .buttonStyle(.bordered)

                            if viewModel.selectedKind == .category || viewModel.selectedKind == .incomeType {
                                Button("Move to subtype") {
                                    moveToSubtypeContext = row
                                    moveTarget = ""
                                }
                                .buttonStyle(.bordered)
                            }

                            if viewModel.selectedKind == .subcategory || viewModel.selectedKind == .incomeSubtype {
                                HStack {
                                    Button("Move subtype under parent") {
                                        moveSubtypeContext = row
                                        moveSubtypeTargetParent = ""
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Promote subtype to parent") {
                                        promoteSubtypeContext = row
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            Button("Delete", role: .destructive) {
                                rowPendingDelete = row
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
                if viewModel.trackingMismatchCount > 0 {
                    Section("Tracking Data Warning") {
                        Text("Detected \(viewModel.trackingMismatchCount) tracking rows not reflected in option flags. Showing effective tracking state.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                if let inlineError = viewModel.inlineError {
                    Section("Error") {
                        Text(inlineError).foregroundStyle(.red).font(.footnote)
                    }
                }
                if let successText = viewModel.successText {
                    Section("Status") {
                        Text(successText).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Options")
            .refreshable { await viewModel.refresh() }
            .alert("Delete option?", isPresented: Binding(get: { rowPendingDelete != nil }, set: { if !$0 { rowPendingDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let row = rowPendingDelete {
                        Task {
                            await viewModel.remove(kind: viewModel.selectedKind, value: row.value, parentValue: row.parentValue)
                            rowPendingDelete = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { rowPendingDelete = nil }
            }
            .sheet(item: $moveToSubtypeContext) { row in
                NavigationStack {
                    Form {
                        Picker("Target parent", selection: $moveTarget) {
                            Text("Select Parent").tag("")
                            ForEach(viewModel.moveToSubtypeTargets(excluding: row.value), id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                    }
                    .navigationTitle("Move To Subtype")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { moveToSubtypeContext = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Move") {
                                Task {
                                    await viewModel.moveToSubtype(kind: viewModel.selectedKind, sourceValue: row.value, targetValue: moveTarget)
                                    moveToSubtypeContext = nil
                                }
                            }
                            .disabled(moveTarget.isEmpty)
                        }
                    }
                }
            }
            .sheet(item: $moveSubtypeContext) { row in
                NavigationStack {
                    Form {
                        Picker("Target parent", selection: $moveSubtypeTargetParent) {
                            Text("Select Parent").tag("")
                            ForEach(viewModel.parentChoicesExcluding(row.parentValue), id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                    }
                    .navigationTitle("Move Subtype")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { moveSubtypeContext = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Move") {
                                guard let sourceParent = row.parentValue else { return }
                                Task {
                                    await viewModel.moveSubtype(kind: viewModel.selectedKind, value: row.value, sourceParentValue: sourceParent, targetParentValue: moveSubtypeTargetParent)
                                    moveSubtypeContext = nil
                                }
                            }
                            .disabled(moveSubtypeTargetParent.isEmpty || row.parentValue == nil)
                        }
                    }
                }
            }
            .sheet(item: $promoteSubtypeContext) { row in
                NavigationStack {
                    Form {
                        Text("Promote '\(row.value)' from subtype to parent?")
                    }
                    .navigationTitle("Promote Subtype")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { promoteSubtypeContext = nil }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Promote") {
                                guard let sourceParent = row.parentValue else { return }
                                Task {
                                    await viewModel.promoteSubtype(kind: viewModel.selectedKind, value: row.value, parentValue: sourceParent)
                                    promoteSubtypeContext = nil
                                }
                            }
                        }
                    }
                }
            }
        }
        .task { viewModel.onAppear() }
    }

    private func color(from hex: String) -> Color? {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6, let value = Int(clean, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0
        return Color(red: red, green: green, blue: blue)
    }
}

private extension UserOptionRow {
    var selfKey: String { "\(value)|\(parentValue ?? "")" }
}

private extension OptionsDisplayRow {
    var selfKey: String { "\(value)|\(parentValue ?? "")" }
}

@MainActor
final class QuickAddFormViewModel: ObservableObject {
    @Published var kind: QuickAddKind = .expense
    @Published var title: String = ""
    @Published var amountText: String = ""
    @Published var selectedOption: String = "General"
    @Published var newOptionName: String = ""
    @Published private(set) var inlineError: String?
    @Published private(set) var optionChoices: [String] = ["General", "Home", "Work"]

    func submit() -> Bool {
        inlineError = nil

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            inlineError = "Title is required."
            return false
        }

        guard let amount = Decimal(string: amountText), amount > 0 else {
            inlineError = "Amount must be greater than zero."
            return false
        }

        return true
    }

    func addOptionIfNeeded() {
        let normalized = newOptionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            inlineError = "Option name cannot be empty."
            return
        }
        guard !optionChoices.contains(normalized) else {
            inlineError = "Option already exists."
            selectedOption = normalized
            return
        }
        optionChoices.append(normalized)
        optionChoices.sort()
        selectedOption = normalized
        newOptionName = ""
        inlineError = nil
    }

    func reset() {
        title = ""
        amountText = ""
        selectedOption = optionChoices.first ?? "General"
        inlineError = nil
    }
}

private struct FeatureRootView: View {
    let tab: AppTab
    let userId: String
    let api: ConvexAPI
    let onSignOut: () -> Void
    let onQuickAdd: () -> Void

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var selectedFilters: Set<String> = []
    @State private var selectedMonth = Date()
    @State private var rangeStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var rangeEnd = Date()

    var body: some View {
        Group {
            if tab == .expenses {
                ExpensesFeatureView(api: api)
            } else if tab == .incomings {
                IncomingsFeatureView(api: api)
            } else if tab == .breakdown {
                BreakdownFeatureView(api: api)
            } else if tab == .recurrings {
                RecurringsFeatureView(api: api)
            } else if tab == .tracking {
                TrackingFeatureView(api: api)
            } else if tab == .notepad {
                NotepadFeatureView(api: api)
            } else if tab == .options {
                OptionsFeatureView(api: api)
            } else if tab == .user {
                UserFeatureView(userId: userId, onSignOut: onSignOut)
            } else {
                List {
            Section {
                DebouncedSearchField(text: $searchText) { value in
                    debouncedSearch = value
                }
                MultiSelectFilterButton(
                    title: "Filters",
                    choices: ["Personal", "Business", "Shared", "Archived"],
                    selected: $selectedFilters
                )
                MonthNavigator(month: $selectedMonth)
                DateRangePickerButton(startDate: $rangeStart, endDate: $rangeEnd)
            }

            Section("State") {
                Text("Search: \(debouncedSearch.isEmpty ? "None" : debouncedSearch)")
                Text("Filters: \(selectedFilters.sorted().joined(separator: ", ").isEmpty ? "None" : selectedFilters.sorted().joined(separator: ", "))")
            }

            Section("Navigation") {
                NavigationLink(value: ShellRoute.detail(title: "\(tab.title) Details")) {
                    Label("Open detail", systemImage: "arrow.right.circle")
                }
            }

            if tab == .options {
                Section("Session") {
                    Text("Signed in as \(userId)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Sign Out", role: .destructive, action: onSignOut)
                        .accessibilityIdentifier("sign_out_button")
                }
            }
        }
                .listStyle(.insetGrouped)
                .navigationTitle(tab.title)
                .navigationDestination(for: ShellRoute.self) { route in
            switch route {
            case .detail(let title):
                LoadStateView(state: .content) {
                    Text(title)
                        .font(.title3.weight(.medium))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
                }
                .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onQuickAdd()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("quick_add_button")
                .accessibilityLabel("Quick Add")
            }
                }
            }
        }
    }
}

private struct UserFeatureView: View {
    let userId: String
    let onSignOut: () -> Void

    var body: some View {
        List {
            Section("Account") {
                LabeledContent("Username", value: userId)
                    .accessibilityIdentifier("user_username_value")
            }

            Section {
                Button("Sign Out", role: .destructive, action: onSignOut)
                    .accessibilityIdentifier("sign_out_button")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("User")
    }
}

private struct BreakdownMetricCard: View {
    let title: String
    let total: String
    let perMonth: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(total).font(.title2.weight(.bold))
                Spacer()
                Text("\(perMonth) /month").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.45), lineWidth: 1)
        )
    }
}

@MainActor
private final class BreakdownViewModel: ObservableObject {
    @Published var state: ViewLoadState = .loading
    @Published var searchText = ""
    @Published var selectedFilters: Set<String> = []
    @Published var month = Date()
    @Published var startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @Published var endDate = Date()
    @Published var summary: SummaryRangeResponse?

    private let api: ConvexAPI
    private let calendar = LedgerScopeLogic.calendar

    init(api: ConvexAPI) {
        self.api = api
        let today = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? today
        startDate = monthStart
        endDate = monthEnd
    }

    func onAppear() {
        Task {
            await load()
        }
    }

    func syncMonthToRange() {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
        startDate = monthStart
        endDate = monthEnd
        Task { await load() }
    }

    func load() async {
        let shouldShowFullScreenError = !state.hasLoadedContent
        if shouldShowFullScreenError { state = .loading }
        do {
            summary = try await api.summaries.range(.init(startDate: LedgerScopeLogic.isoDate(startDate), endDate: LedgerScopeLogic.isoDate(endDate)))
            state = .content
        } catch {
            if shouldShowFullScreenError {
                state = .error(message: "Failed to load breakdown")
            }
        }
    }
}

private struct BreakdownFeatureView: View {
    @StateObject private var viewModel: BreakdownViewModel

    init(api: ConvexAPI) {
        _viewModel = StateObject(wrappedValue: BreakdownViewModel(api: api))
    }

    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "ILS"
        f.locale = Locale(identifier: "he_IL")
        return f
    }()

    var body: some View {
        LoadStateView(state: viewModel.state, retry: { Task { await viewModel.load() } }) {
            List {
                Section {
                    DebouncedSearchField(text: $viewModel.searchText) { _ in }
                    MultiSelectFilterButton(title: "Filters", choices: [], selected: $viewModel.selectedFilters)
                    MonthNavigator(month: $viewModel.month)
                        .onChange(of: viewModel.month) { _, _ in viewModel.syncMonthToRange() }
                    DateRangePickerButton(startDate: $viewModel.startDate, endDate: $viewModel.endDate)
                        .onChange(of: viewModel.startDate) { _, _ in Task { await viewModel.load() } }
                        .onChange(of: viewModel.endDate) { _, _ in Task { await viewModel.load() } }
                }

                if let summary = viewModel.summary {
                    Section {
                        BreakdownMetricCard(title: "TOTAL INCOMINGS", total: money(summary.totals.effectiveIncomings), perMonth: monthly(value: summary.totals.effectiveIncomings, count: summary.monthlyBuckets.count), tint: .green)
                        BreakdownMetricCard(title: "TOTAL EXPENSES", total: money(summary.totals.effectiveExpenses), perMonth: monthly(value: summary.totals.effectiveExpenses, count: summary.monthlyBuckets.count), tint: .red)
                        BreakdownMetricCard(title: "TOTAL SAVINGS", total: money(summary.totals.effectiveNet), perMonth: monthly(value: summary.totals.effectiveNet, count: summary.monthlyBuckets.count), tint: .blue)
                    }
                }

                if let summary = viewModel.summary {
                    Section("Per Month") {
                        ForEach(summary.monthlyBuckets, id: \.month) { row in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.month).font(.headline)
                                HStack {
                                    Text("Incomings \(money(row.effectiveIncomings))")
                                    Spacer()
                                    Text("Expenses \(money(row.effectiveExpenses))")
                                    Spacer()
                                    Text("Savings \(money(row.effectiveNet))").foregroundStyle(row.effectiveNet >= 0 ? .green : .red)
                                }
                                .font(.footnote)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Breakdown")
            .refreshable { await viewModel.load() }
        }
        .task { viewModel.onAppear() }
    }

    private func money(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "₪\(value)"
    }

    private func monthly(value: Double, count: Int) -> String {
        guard count > 0 else { return money(value) }
        return money(value / Double(count))
    }
}

struct AppShellView: View {
    let userId: String
    let api: ConvexAPI
    let onSignOut: () -> Void

    @SceneStorage("shell.selectedTab") private var selectedTabRaw = AppTab.defaultTab.rawValue
    @SceneStorage("shell.path.expenses") private var expensesPathData: Data?
    @SceneStorage("shell.path.incomings") private var incomingsPathData: Data?
    @SceneStorage("shell.path.breakdown") private var breakdownPathData: Data?
    @SceneStorage("shell.path.recurrings") private var recurringsPathData: Data?
    @SceneStorage("shell.path.tracking") private var trackingPathData: Data?
    @SceneStorage("shell.path.notepad") private var notepadPathData: Data?
    @SceneStorage("shell.path.options") private var optionsPathData: Data?
    @SceneStorage("shell.path.user") private var userPathData: Data?

    @State private var selectedTab: AppTab = .defaultTab
    @State private var pathByTab: [AppTab: NavigationPath] = [:]
    @State private var quickAddPresented = false
    @StateObject private var quickAddVM = QuickAddFormViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack(path: binding(for: tab)) {
                    FeatureRootView(tab: tab, userId: userId, api: api, onSignOut: onSignOut) {
                        quickAddPresented = true
                    }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
                .accessibilityIdentifier("tab_\(tab.rawValue)")
            }
        }
        .sheet(isPresented: $quickAddPresented, onDismiss: {
            quickAddVM.reset()
        }) {
            QuickAddSheet(viewModel: quickAddVM) {
                quickAddPresented = false
            }
            .presentationDetents([.medium, .large])
            .accessibilityIdentifier("quick_add_sheet")
        }
        .onAppear {
            restoreSelectedTabIfNeeded()
            restorePathsIfNeeded()
        }
        .onChange(of: selectedTab) { _, newValue in
            selectedTabRaw = newValue.rawValue
        }
        .onOpenURL { url in
            apply(deepLink: ShellDeepLink.parse(url: url))
        }
    }

    private func binding(for tab: AppTab) -> Binding<NavigationPath> {
        Binding {
            pathByTab[tab, default: NavigationPath()]
        } set: { newValue in
            pathByTab[tab] = newValue
            persist(path: newValue, for: tab)
        }
    }

    private func restoreSelectedTabIfNeeded() {
        selectedTab = AppTab(rawValue: selectedTabRaw) ?? .defaultTab
    }

    private func restorePathsIfNeeded() {
        for tab in AppTab.allCases {
            pathByTab[tab] = restorePath(for: tab)
        }
    }

    private func apply(deepLink: ShellDeepLink?) {
        guard let deepLink else { return }
        if let tab = deepLink.tab {
            selectedTab = tab
        }
        if let quickAddKind = deepLink.quickAddKind {
            quickAddVM.kind = quickAddKind
            quickAddPresented = true
        }
    }

    private func persist(path: NavigationPath, for tab: AppTab) {
        guard let codable = path.codable else {
            setPathData(nil, for: tab)
            return
        }

        do {
            let data = try JSONEncoder().encode(codable)
            setPathData(data, for: tab)
        } catch {
            setPathData(nil, for: tab)
        }
    }

    private func restorePath(for tab: AppTab) -> NavigationPath {
        guard let data = pathData(for: tab) else { return NavigationPath() }

        do {
            let codable = try JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data)
            return NavigationPath(codable)
        } catch {
            return NavigationPath()
        }
    }

    private func pathData(for tab: AppTab) -> Data? {
        switch tab {
        case .expenses: return expensesPathData
        case .incomings: return incomingsPathData
        case .breakdown: return breakdownPathData
        case .recurrings: return recurringsPathData
        case .tracking: return trackingPathData
        case .notepad: return notepadPathData
        case .options: return optionsPathData
        case .user: return userPathData
        }
    }

    private func setPathData(_ value: Data?, for tab: AppTab) {
        switch tab {
        case .expenses: expensesPathData = value
        case .incomings: incomingsPathData = value
        case .breakdown: breakdownPathData = value
        case .recurrings: recurringsPathData = value
        case .tracking: trackingPathData = value
        case .notepad: notepadPathData = value
        case .options: optionsPathData = value
        case .user: userPathData = value
        }
    }
}

private struct QuickAddSheet: View {
    @ObservedObject var viewModel: QuickAddFormViewModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $viewModel.kind) {
                    ForEach(QuickAddKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                TextField("Title", text: $viewModel.title)
                TextField("Amount", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)

                Picker("Option", selection: $viewModel.selectedOption) {
                    ForEach(viewModel.optionChoices, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }

                Section("Add missing option") {
                    TextField("New option", text: $viewModel.newOptionName)
                    Button("Add Option") {
                        viewModel.addOptionIfNeeded()
                    }
                }

                if let inlineError = viewModel.inlineError, !inlineError.isEmpty {
                    Text(inlineError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityIdentifier("quick_add_inline_error")
                }
            }
            .navigationTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        if viewModel.submit() {
                            onClose()
                        }
                    }
                    .accessibilityIdentifier("quick_add_create")
                }
            }
        }
    }
}
