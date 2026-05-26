import Foundation

enum EffectiveAmountMode: String, Codable, CaseIterable {
    case auto
    case manual
}

enum ScopeMatchStatus: String, Codable, CaseIterable {
    case full
    case monthYearsOnly
    case dateOnly
}

struct MonthYear: Hashable, Codable, Comparable {
    let rawValue: String

    init?(_ rawValue: String) {
        guard rawValue.range(of: #"^\d{4}-(0[1-9]|1[0-2])$"#, options: .regularExpression) != nil else {
            return nil
        }
        self.rawValue = rawValue
    }

    static func < (lhs: MonthYear, rhs: MonthYear) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct DateScope: Equatable {
    var startDate: Date
    var endDate: Date
    var includeMonthYearOverlapOutsideDate: Bool

    func request(calendar: Calendar) -> DateScopeRequest {
        let targetMonths = LedgerScopeLogic.targetMonths(startDate: startDate, endDate: endDate, calendar: calendar).map(\ .rawValue)
        return DateScopeRequest(
            startDate: LedgerScopeLogic.isoDate(startDate),
            endDate: LedgerScopeLogic.isoDate(endDate),
            targetMonths: targetMonths,
            includeMonthYearOverlapOutsideDate: includeMonthYearOverlapOutsideDate
        )
    }
}

struct Expense: Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let account: String
    let category: String
    let subcategory: String?
    let amount: Double
    let effectiveAmount: Double
    let effectiveAmountMode: EffectiveAmountMode
    let monthYears: [MonthYear]
    let date: Date
    let paidTo: String
    let notes: String?
    let comments: String?
    let expenseId: String
    let baseExpenseId: String?
    let baseExpenseLabel: String?
    let subExpenseId: String?

    var isGrouped: Bool { baseExpenseId != nil || subExpenseId != nil }
}

struct Incoming: Identifiable, Equatable {
    let id: String
    let name: String
    let paidBy: String
    let incomeType: String
    let incomeSubtype: String?
    let account: String
    let amount: Double
    let effectiveAmount: Double
    let effectiveAmountMode: EffectiveAmountMode
    let monthYears: [MonthYear]
    let date: Date
    let notes: String?
    let comments: String?
    let incomingId: String
    let baseIncomingId: String?
    let subIncomingId: String?

    var isGrouped: Bool { baseIncomingId != nil || subIncomingId != nil }
}

enum LedgerScopeLogic {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static func targetMonths(startDate: Date, endDate: Date, calendar: Calendar = calendar) -> [MonthYear] {
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)) ?? startDate
        let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate)) ?? endDate
        guard startMonth <= endMonth else { return [] }

        var result: [MonthYear] = []
        var cursor = startMonth
        while cursor <= endMonth {
            if let month = MonthYear(monthFormatter.string(from: cursor)) {
                result.append(month)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    static func monthBounds(for month: MonthYear, calendar: Calendar = calendar) -> (start: Date, end: Date)? {
        guard let date = monthFormatter.date(from: month.rawValue),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) else {
            return nil
        }
        return (start, end)
    }

    static func scopeStatus(date: Date, monthYears: [MonthYear], scope: DateScope, calendar: Calendar = calendar) -> ScopeMatchStatus {
        let inDate = date >= startOfDay(scope.startDate, calendar: calendar) && date <= endOfDay(scope.endDate, calendar: calendar)
        let targetMonths = Set(targetMonths(startDate: scope.startDate, endDate: scope.endDate, calendar: calendar))
        let monthMatch = !targetMonths.isDisjoint(with: Set(monthYears))

        if inDate && monthMatch { return .full }
        if monthMatch { return .monthYearsOnly }
        return .dateOnly
    }

    static func isoDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func parseISODate(_ value: String) -> Date? {
        isoFormatter.date(from: value)
    }

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    private static func endOfDay(_ date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
}

extension Expense {
    init(dto: ExpenseDTO) {
        id = dto._id
        name = dto.expense
        type = dto.type ?? ""
        account = dto.account ?? ""
        category = dto.category ?? ""
        subcategory = dto.subcategory
        amount = dto.amount
        effectiveAmount = dto.effectiveAmount ?? dto.amount
        effectiveAmountMode = EffectiveAmountMode(rawValue: dto.effectiveAmountMode ?? "auto") ?? .auto
        monthYears = dto.monthYears.compactMap(MonthYear.init)
        date = LedgerScopeLogic.parseISODate(dto.date) ?? Date()
        paidTo = dto.paidTo ?? ""
        notes = dto.notes
        comments = dto.comments
        expenseId = dto.expenseId
        baseExpenseId = dto.baseExpenseId
        baseExpenseLabel = dto.baseExpenseLabel
        subExpenseId = dto.subExpenseId
    }
}

extension Incoming {
    init(dto: IncomingDTO) {
        id = dto._id
        name = dto.incoming
        paidBy = dto.paidBy ?? ""
        incomeType = dto.incomeType ?? ""
        incomeSubtype = dto.incomeSubtype
        account = dto.account ?? ""
        amount = dto.amount
        effectiveAmount = dto.effectiveAmount ?? dto.amount
        effectiveAmountMode = EffectiveAmountMode(rawValue: dto.effectiveAmountMode ?? "auto") ?? .auto
        monthYears = dto.monthYears.compactMap(MonthYear.init)
        date = LedgerScopeLogic.parseISODate(dto.date) ?? Date()
        notes = dto.notes
        comments = dto.comments
        incomingId = dto.incomingId
        baseIncomingId = dto.baseIncomingId
        subIncomingId = dto.subIncomingId
    }
}
