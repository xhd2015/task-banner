import Foundation

struct RemoteResponse<T: Decodable>:Decodable{
    let code: Int
    let msg: String?
    let data: T
}
struct EmptyResponse: Codable {}

struct TaskUpdateRequest: Encodable {
    let taskID: Int64
    let update: TaskUpdate
}

func makeHttpGet<T: Decodable>(api:String, params: [URLQueryItem]?)  async throws -> T {
    return try await makeHttpRequest(api: api, method: "GET", params: params, body: nil)
}

func makeHttpPost<T: Decodable>(api:String, body: any Encodable)  async throws -> T {
    return try await makeHttpRequest(api: api, method: "POST", params: nil, body: body)
}

func makeHttpRequest<T: Decodable>(api:String,method:String, params: [URLQueryItem]?,body: (any Encodable)?)  async throws -> T {
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
    request.httpMethod = method
    if let body = body {
        request.httpBody = try JSONEncoder().encode(body)
    }
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

    func addTask(_ task: TaskItem) async throws -> TaskItem {
        return try await makeHttpPost(api: "/api/addTask", body: task) as TaskItem
    }

    func updateTask(taskId: Int64, update: TaskUpdate) async throws {
        let request = TaskUpdateRequest(taskID: taskId, update: update)
        let _: EmptyResponse = try await makeHttpPost(api: "/api/updateTask", body: request)
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
}
