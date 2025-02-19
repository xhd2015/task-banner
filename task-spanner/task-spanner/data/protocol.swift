// Define protocol for data storage

// Structure to describe task updates
struct TaskUpdate: Codable {
    var title: String?
    var status: TaskStatus?
    var notes: [String]?
    // Add more fields as needed
}

protocol TaskStorage {
    func saveTasks(_ tasks: [TaskItem]) async throws
    func loadTasks() async throws -> [TaskItem]
    func addTask(_ task: TaskItem) async throws -> TaskItem
    func removeTask(taskId: Int64) async throws
    func updateTask(taskId: Int64, update: TaskUpdate) async throws
    func exchangeOrder(aID: Int64, bID: Int64) async throws
    func addTaskNote(taskId: Int64, note: String) async throws
    func updateTaskNote(taskId: Int64, noteIndex: Int, newText: String) async throws
}
