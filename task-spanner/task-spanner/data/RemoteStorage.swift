import Foundation

// Remote storage implementation
class RemoteTaskStorage: TaskStorage {
    func loadTasks(mode: TaskMode?) async throws -> [TaskItem] {
        return []
    }
    
    func removeTask(taskId: Int64) async throws {
        
    }
    
    func exchangeOrder(aID: Int64, bID: Int64) async throws {
        
    }
    
    func addTaskNote(taskId: Int64, note: String) async throws {
        
    }
    
    func updateTaskNote(taskId: Int64, noteIndex: Int, newText: String) async throws {
        
    }
    
    private let baseURL: URL
    
    init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!
    }
    
    func saveTasks(_ tasks: [TaskItem]) async throws {
        let url = baseURL.appendingPathComponent("tasks")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoded = try JSONEncoder().encode(tasks)
        let (_, response) = try await URLSession.shared.upload(for: request, from: encoded)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func loadTasks() async throws -> [TaskItem] {
        let url = baseURL.appendingPathComponent("tasks")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([TaskItem].self, from: data)
    }
    
    func addTask(_ task: TaskItem) async throws -> TaskItem {
        let endpoint = task.parentId != nil ? 
            "tasks/\(task.parentId!)/subtasks" : 
            "task"
            
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoded = try JSONEncoder().encode(task)
        let (data, response) = try await URLSession.shared.upload(for: request, from: encoded)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(TaskItem.self, from: data)
    }
    
    func updateTask(taskId: Int64, update: TaskUpdate) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(taskId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoded = try JSONEncoder().encode(update)
        let (_, response) = try await URLSession.shared.upload(for: request, from: encoded)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
