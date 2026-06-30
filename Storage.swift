import Foundation

enum TimeCircleStorage {
    private static let tasksKey = "timeCircleTasks"
    private static let sessionsKey = "timeCircleSessions"
    private static let activeTrackingStateKey = "timeCircleActiveTrackingState"

    static let defaultTasks = [
        TaskItem(name: "Learning French", color: .red),
        TaskItem(name: "Gym", color: .blue)
    ]

    static func save(tasks: [TaskItem], sessions: [SessionItem]) {
        saveCodable(tasks, forKey: tasksKey)
        saveCodable(sessions, forKey: sessionsKey)
    }

    static func loadTasks() -> [TaskItem]? {
        loadCodable([TaskItem].self, forKey: tasksKey)
    }

    static func loadSessions() -> [SessionItem]? {
        loadCodable([SessionItem].self, forKey: sessionsKey)
    }

    static func save(activeTrackingState: ActiveTrackingState?) {
        guard let activeTrackingState else {
            UserDefaults.standard.removeObject(forKey: activeTrackingStateKey)
            return
        }

        saveCodable(activeTrackingState, forKey: activeTrackingStateKey)
    }

    static func loadActiveTrackingState() -> ActiveTrackingState? {
        loadCodable(ActiveTrackingState.self, forKey: activeTrackingStateKey)
    }

    static func clearActiveTrackingState() {
        UserDefaults.standard.removeObject(forKey: activeTrackingStateKey)
    }

    private static func saveCodable<T: Codable>(_ value: T, forKey key: String) {
        if let encodedValue = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encodedValue, forKey: key)
        }
    }

    private static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
