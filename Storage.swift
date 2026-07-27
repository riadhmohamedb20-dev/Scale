import Foundation

struct ScaleBackup: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var tasks: [TaskItem]
    var sessions: [SessionItem]
    var toDoItems: [ToDoItem]
    var appearanceModeRawValue: String?

    init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        tasks: [TaskItem],
        sessions: [SessionItem],
        toDoItems: [ToDoItem] = [],
        appearanceModeRawValue: String?
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.tasks = tasks
        self.sessions = sessions
        self.toDoItems = toDoItems
        self.appearanceModeRawValue = appearanceModeRawValue
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case tasks
        case sessions
        case toDoItems
        case appearanceModeRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        tasks = try container.decode([TaskItem].self, forKey: .tasks)
        sessions = try container.decode([SessionItem].self, forKey: .sessions)
        toDoItems = try container.decodeIfPresent([ToDoItem].self, forKey: .toDoItems) ?? []
        appearanceModeRawValue = try container.decodeIfPresent(String.self, forKey: .appearanceModeRawValue)
    }

    func validate() throws {
        guard schemaVersion >= 1 else {
            throw ScaleBackupError.unsupportedVersion
        }

        guard Set(tasks.map(\.id)).count == tasks.count,
              Set(sessions.map(\.id)).count == sessions.count
        else {
            throw ScaleBackupError.duplicateData
        }
    }
}

enum ScaleBackupError: Error {
    case unsupportedVersion
    case duplicateData
}

enum TimeCircleStorage {
    private static let tasksKey = "timeCircleTasks"
    private static let sessionsKey = "timeCircleSessions"
    private static let toDoItemsKey = "timeCircleToDoItems"
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

    static func save(toDoItems: [ToDoItem]) {
        saveCodable(toDoItems, forKey: toDoItemsKey)
    }

    static func loadToDoItems() -> [ToDoItem]? {
        loadCodable([ToDoItem].self, forKey: toDoItemsKey)
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

    static func backupData(
        tasks: [TaskItem],
        sessions: [SessionItem],
        toDoItems: [ToDoItem],
        appearanceModeRawValue: String?
    ) throws -> Data {
        let backup = ScaleBackup(
            tasks: tasks,
            sessions: sessions,
            toDoItems: toDoItems,
            appearanceModeRawValue: appearanceModeRawValue
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decodeBackup(from data: Data) throws -> ScaleBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(ScaleBackup.self, from: data)
        try backup.validate()
        return backup
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
