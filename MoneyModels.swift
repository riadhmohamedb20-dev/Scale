import SwiftUI

enum MoneyFormat {
    static func currency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let number = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return "\(number) DA"
    }

    static func transactionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    static func transactionDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

/// A debt rolls forward day to day while unpaid — it's visible on every day from `debtDate`
/// onward until checked off. Once paid, it stays visible (as paid) from `debtDate` through
/// `paidDate` inclusive — a fixed historical window — and disappears on every day after that.
///
/// `debtDate` is the user-editable date the debt belongs to and is what drives all of the above.
/// `recordedDate` is separate: the date the debt was actually entered into the app, kept purely
/// for information and never consulted by carry-forward or budget logic.
struct DebtItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var debtDate: Date
    var recordedDate: Date
    var isPaid: Bool
    var paidDate: Date?
    var notes: String
    /// The calendar day of a scheduled payment reminder — nil means no reminder is scheduled.
    /// `scheduledPaymentTime` only matters once this is set (the Time toggle is only available
    /// once Date is enabled); the two combine into a single fire date for the local notification.
    var scheduledPaymentDate: Date?
    var scheduledPaymentTime: Date?
    /// Empty for a manually created debt. Set only when this debt was generated automatically to
    /// cover the portion of an expense the available budget couldn't — inherited from that
    /// expense's own emoji/merchant purely for data-model completeness/consistency.
    var emoji: String
    var merchant: String
    /// Nil for a manually created debt. Non-nil marks this debt as auto-generated to cover the
    /// uncovered portion of the `ExpenseItem` with this id — used to find, update, or remove
    /// exactly this debt when that expense is edited or deleted, and to guarantee that cascade
    /// never touches an unrelated manually created debt.
    var linkedExpenseID: UUID?
    /// The reason the user gave for this debt in the new-debt confirmation step. Never touched by
    /// editing an existing debt — there's no UI for changing it after creation.
    var intention: String

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        debtDate: Date = Date(),
        recordedDate: Date = Date(),
        isPaid: Bool = false,
        paidDate: Date? = nil,
        notes: String = "",
        scheduledPaymentDate: Date? = nil,
        scheduledPaymentTime: Date? = nil,
        emoji: String = "",
        merchant: String = "",
        linkedExpenseID: UUID? = nil,
        intention: String = ""
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.debtDate = debtDate
        self.recordedDate = recordedDate
        self.isPaid = isPaid
        self.paidDate = paidDate
        self.notes = notes
        self.scheduledPaymentDate = scheduledPaymentDate
        self.scheduledPaymentTime = scheduledPaymentTime
        self.emoji = emoji
        self.merchant = merchant
        self.linkedExpenseID = linkedExpenseID
        self.intention = intention
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, amount, debtDate, recordedDate, isPaid, paidDate, notes
        case scheduledPaymentDate, scheduledPaymentTime, emoji, merchant, linkedExpenseID, intention
    }

    // Custom decode so debts saved before notes/reminder/automatic-debt/intention support existed
    // (missing keys) fall back to empty/nil instead of failing to decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        debtDate = try container.decode(Date.self, forKey: .debtDate)
        recordedDate = try container.decode(Date.self, forKey: .recordedDate)
        isPaid = try container.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
        paidDate = try container.decodeIfPresent(Date.self, forKey: .paidDate)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        scheduledPaymentDate = try container.decodeIfPresent(Date.self, forKey: .scheduledPaymentDate)
        scheduledPaymentTime = try container.decodeIfPresent(Date.self, forKey: .scheduledPaymentTime)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        linkedExpenseID = try container.decodeIfPresent(UUID.self, forKey: .linkedExpenseID)
        intention = try container.decodeIfPresent(String.self, forKey: .intention) ?? ""
    }
}

/// A remembered choice from the new-expense/new-debt confirmation step, keyed by a normalized
/// title so it can be found again for the same recurring expense/debt (e.g. via Recent Expenses)
/// without being a blanket setting that applies to every expense or debt.
struct IntentionPreference: Equatable, Codable {
    var intention: String
    var doNotShowAgain: Bool
}

/// A dated top-up to the available budget, kept as its own record (rather than folded
/// immediately into a running total) so the budget as of any past day can be recomputed
/// from source data instead of drifting off a mutated live number.
struct MoneyTopUp: Identifiable, Equatable, Codable {
    var id = UUID()
    var amount: Double
    var date: Date

    init(id: UUID = UUID(), amount: Double, date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.date = date
    }
}

/// A budget edit that takes effect from `effectiveDate` onward — "Update Today's Budget". The
/// baseline in force for any given day is whichever change has the latest `effectiveDate` on or
/// before that day; days before every change still use the original default budget. This is what
/// lets a budget edit shift the future without rewriting the past.
struct BudgetBaselineChange: Identifiable, Equatable, Codable {
    var id = UUID()
    var effectiveDate: Date
    var value: Double

    init(id: UUID = UUID(), effectiveDate: Date, value: Double) {
        self.id = id
        self.effectiveDate = effectiveDate
        self.value = value
    }
}

struct ExpenseItem: Identifiable, Equatable, Codable {
    static let defaultEmoji = "🧾"

    var id = UUID()
    var title: String
    var merchant: String
    var amount: Double
    var emoji: String
    var date: Date
    var notes: String
    /// The reason the user gave for this expense in the new-expense confirmation step. Never
    /// touched by editing an existing expense — there's no UI for changing it after creation.
    var intention: String

    init(
        id: UUID = UUID(),
        title: String,
        merchant: String = "",
        amount: Double,
        emoji: String = ExpenseItem.defaultEmoji,
        date: Date = Date(),
        notes: String = "",
        intention: String = ""
    ) {
        self.id = id
        self.title = title
        self.merchant = merchant
        self.amount = amount
        self.emoji = emoji
        self.date = date
        self.notes = notes
        self.intention = intention
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, merchant, amount, emoji, date, notes, intention
    }

    // Custom decode so expenses saved before emoji/notes/intention support existed (no
    // `emoji`/`notes`/`intention` key, possibly a now-removed `category` key still sitting in the
    // encoded JSON) fall back to sensible defaults instead of failing to decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        merchant = try container.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        amount = try container.decode(Double.self, forKey: .amount)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? ExpenseItem.defaultEmoji
        date = try container.decode(Date.self, forKey: .date)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        intention = try container.decodeIfPresent(String.self, forKey: .intention) ?? ""
    }
}
