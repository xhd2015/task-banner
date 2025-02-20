import Foundation

struct RemoteResponse<T: Decodable>:Decodable{
    let code: Int
    let msg: String?
    let data: T
}

func makeHttpGet<T: Decodable>(api:String, params: [URLQueryItem]?)  async throws -> T {
    var components = URLComponents()
    components.scheme = "http"
    components.host = "localhost"
    components.port = 7021
    components.path = api
    if let queryItems = params {
        components.queryItems = queryItems
    }
    guard let url = components.url else {
        throw URLError(.badURL)
    }
    print("Making request to: \(url.absoluteString)")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
        print("Response is not HTTP response")
        throw URLError(.badServerResponse)
    }
    print("Response status code: \(httpResponse.statusCode)")
    if !(200...299).contains(httpResponse.statusCode) {
        if let responseStr = String(data: data, encoding: .utf8) {
            print("Error response body: \(responseStr)")
        }
        throw URLError(.badServerResponse)
    }
    do {
        // resp example: {code:0 ,data:[]}
        let resp = try JSONDecoder().decode(RemoteResponse<T>.self, from: data)
        if resp.code != 0 {
            // with custom error message
            print("Remote error: \(resp.code), msg: \(resp.msg ?? "Unknown error")")
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: resp.msg ?? "Unknown error"])
        }
        return resp.data
    } catch {
        print("Failed to decode response: \(error)")
        if let responseStr = String(data: data, encoding: .utf8) {
            print("Response body: \(responseStr)")
        }
        throw error
    }
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

    func removeTask(taskId: Int64) async throws {
        
    }
    
    func exchangeOrder(aID: Int64, bID: Int64) async throws {
        
    }
    
    func addTaskNote(taskId: Int64, note: String) async throws {
        
    }
    
    func updateTaskNote(taskId: Int64, noteIndex: Int, newText: String) async throws {
        
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
