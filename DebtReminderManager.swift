import Foundation
import UserNotifications

/// Schedules and cancels the local notification that reminds the user to pay a debt.
/// One pending notification per debt, keyed by the debt's own id, so re-scheduling a debt
/// (edit, unpay/repay) always first cancels whatever was there before.
enum DebtReminderManager {
    static func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            case .denied:
                DispatchQueue.main.async { completion(false) }
            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    /// Checks current status without prompting — used to silently reflect an earlier denial in
    /// the UI (e.g. when reopening the edit sheet) without re-triggering the system prompt.
    static func isAuthorizationDenied(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus == .denied) }
        }
    }

    /// The calendar day from `scheduledPaymentDate` combined with the time-of-day from
    /// `scheduledPaymentTime` into a single fire date. Nil unless both are set.
    static func fireDate(for debt: DebtItem) -> Date? {
        guard let scheduledDate = debt.scheduledPaymentDate, let scheduledTime = debt.scheduledPaymentTime else {
            return nil
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: scheduledDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        return calendar.date(from: components)
    }

    /// Cancels whatever reminder currently exists for this debt, then schedules a fresh one if
    /// a fire date exists, isn't already in the past, and the debt isn't currently paid off.
    static func scheduleReminder(for debt: DebtItem) {
        cancelReminder(for: debt.id)

        guard !debt.isPaid, let fireDate = fireDate(for: debt), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Debt Payment Reminder"
        content.body = "Pay \"\(debt.title)\" — \(MoneyFormat.currency(debt.amount))"
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier(for: debt.id), content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminder(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: id)])
    }

    private static func identifier(for id: UUID) -> String {
        "debtPaymentReminder-\(id.uuidString)"
    }
}
