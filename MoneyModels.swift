import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case groceries
    case food
    case bills
    case transport
    case shopping
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .groceries:
            return "Groceries"
        case .food:
            return "Food"
        case .bills:
            return "Bills"
        case .transport:
            return "Transport"
        case .shopping:
            return "Shopping"
        case .other:
            return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .groceries:
            return "cart.fill"
        case .food:
            return "fork.knife"
        case .bills:
            return "doc.text.fill"
        case .transport:
            return "car.fill"
        case .shopping:
            return "bag.fill"
        case .other:
            return "ellipsis"
        }
    }

    var iconBackground: Color {
        switch self {
        case .groceries:
            return Color(red: 0.82, green: 0.62, blue: 0.15)
        case .food:
            return Color(red: 0.88, green: 0.42, blue: 0.24)
        case .bills:
            return Color(red: 0.24, green: 0.44, blue: 0.94)
        case .transport:
            return Color(red: 0.18, green: 0.62, blue: 0.58)
        case .shopping:
            return Color(red: 0.62, green: 0.35, blue: 0.86)
        case .other:
            return Color(red: 0.32, green: 0.32, blue: 0.34)
        }
    }
}

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

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

struct ExpenseItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var merchant: String
    var amount: Double
    var category: ExpenseCategory
    var date: Date

    init(
        id: UUID = UUID(),
        title: String,
        merchant: String = "",
        amount: Double,
        category: ExpenseCategory,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.merchant = merchant
        self.amount = amount
        self.category = category
        self.date = date
    }
}
