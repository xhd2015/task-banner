import Foundation

struct TaskUpdateRequest: Encodable {
    let taskID: Int64
    let update: TaskUpdate
}

// Remote storage implementation
class RemoteTaskStorage: TaskStorage {
    // private let baseURL: String = "http://localhost:7021"

    private let baseURL: URL

    init(baseURL: String = "http://localhost:7021") {
        self.baseURL = URL(string: baseURL)!
    }

    func loadTasks(mode: TaskMode?) async throws -> [TaskItem] {
        return try await makeHttpGet(api: "/api/listTasks", params: mode != nil ? [URLQueryItem(name: "mode", value: mode?.rawValue)] : nil) as [TaskItem]
    }

    func addTask(_ task: TaskItem) async throws -> TaskItem {
        return try await makeHttpPost(api: "/api/addTask", body: task) as TaskItem
    }

    func updateTask(taskId: Int64, update: TaskUpdate) async throws {
        let request = TaskUpdateRequest(taskID: taskId, update: update)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/updateTask", body: request)
    }

    func removeTask(taskId: Int64) async throws {
        struct RemoveTaskRequest: Encodable {
            let taskID: Int64
        }
        let request = RemoveTaskRequest(taskID: taskId)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/removeTask", body: request)
    }
    
    func exchangeOrder(aID: Int64, bID: Int64) async throws {
        struct ExchangeOrderRequest: Encodable {
            let taskID: Int64
            let exchangeTaskID: Int64
        }
        let request = ExchangeOrderRequest(taskID: aID, exchangeTaskID: bID)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/exchangeOrder", body: request)
    }
    
    func addTaskNote(taskId: Int64, note: String) async throws {
        struct AddTaskNoteRequest: Encodable {
            let taskID: Int64
            let note: String
        }
        let request = AddTaskNoteRequest(taskID: taskId, note: note)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/addTaskNote", body: request)
    }
    
    func updateTaskNote(taskId: Int64, noteIndex: Int, newText: String) async throws {
        struct UpdateTaskNoteRequest: Encodable {
            let taskID: Int64
            let noteIndex: Int
            let newText: String
        }
        let request = UpdateTaskNoteRequest(taskID: taskId, noteIndex: noteIndex, newText: newText)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/updateTaskNote", body: request)
    }
    
    func saveTasks(_ tasks: [TaskItem]) async throws {
        struct SaveTasksRequest: Encodable {
            let tasks: [TaskItem]
        }
        let request = SaveTasksRequest(tasks: tasks)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/saveTasks", body: request)
    }
}
