import Foundation

// Define protocol for data storage

// Structure to describe task updates
struct TaskUpdate: Codable {
    var title: String?
    var status: TaskStatus?
    var notes: [String]?
    var mode: TaskMode?  // Add mode to task updates
    
    enum CodingKeys: String, CodingKey {
        case title, status, notes, mode
    }
    
    init(title: String? = nil, status: TaskStatus? = nil, notes: [String]? = nil, mode: TaskMode? = nil) {
        self.title = title
        self.status = status
        self.notes = notes
        self.mode = mode
    }
}

protocol TaskStorage {
    func saveTasks(_ tasks: [TaskItem]) async throws
    func loadTasks(mode: TaskMode?) async throws -> [TaskItem]  // Add mode parameter
    func addTask(_ task: TaskItem) async throws -> TaskItem
    func removeTask(taskId: Int64) async throws
    func updateTask(taskId: Int64, update: TaskUpdate) async throws
    func exchangeOrder(aID: Int64, bID: Int64) async throws
    func addTaskNote(taskId: Int64, note: String) async throws
    func updateTaskNote(taskId: Int64, noteIndex: Int, newText: String) async throws
}
