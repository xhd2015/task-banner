import Foundation
import AppKit
import SwiftUI

// First, make ActiveTask codable so we can save it
struct ActiveTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var startTime: Date
    var parentId: UUID?  // Add this field to track parent task
    var subTasks: [ActiveTask]  // New field
    
    init(title: String, startTime: Date = Date(), parentId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.parentId = parentId
        self.subTasks = []
    }
}

// Define protocol for data storage
protocol TaskStorage {
    func saveTasks(_ tasks: [ActiveTask]) async throws
    func loadTasks() async throws -> [ActiveTask]
    func addTask(_ task: ActiveTask) async throws
    func addSubTask(parentId: UUID, title: String) async throws
}

// Local storage implementation
class LocalTaskStorage: TaskStorage {
    func saveTasks(_ tasks: [ActiveTask]) async throws {
        do {
            let encoded = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(encoded, forKey: "savedTasks")
            print("Successfully saved tasks: \(tasks.count) root tasks")
        } catch {
            print("Error saving tasks: \(error)")
            throw error
        }
    }
    
    func loadTasks() async throws -> [ActiveTask] {
        guard let savedTasks = UserDefaults.standard.data(forKey: "savedTasks") else {
            print("No saved tasks found in UserDefaults")
            return []
        }
        
        do {
            let decodedTasks = try JSONDecoder().decode([ActiveTask].self, from: savedTasks)
            print("Successfully loaded tasks: \(decodedTasks.count) root tasks")
            print("Tasks details: \(decodedTasks.map { "id: \($0.id), title: \($0.title), subTasks: \($0.subTasks.count)" })")
            return decodedTasks
        } catch {
            print("Error decoding tasks: \(error)")
            print("Raw data: \(String(data: savedTasks, encoding: .utf8) ?? "unable to convert to string")")
            return []
        }
    }
    
    func addTask(_ task: ActiveTask) async throws {
        var currentTasks = try await loadTasks()
        currentTasks.append(task)
        try await saveTasks(currentTasks)
    }
    
    func addSubTask(parentId: UUID, title: String) async throws {
        var currentTasks = try await loadTasks()
        let subTask = ActiveTask(title: title, parentId: parentId)
        
        // Find the parent task and add the subtask to its subTasks array
        if let parentIndex = currentTasks.firstIndex(where: { $0.id == parentId }) {
            currentTasks[parentIndex].subTasks.append(subTask)
            try await saveTasks(currentTasks)
        }
    }
}

// Remote storage implementation
class RemoteTaskStorage: TaskStorage {
    private let baseURL: URL
    
    init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!
    }
    
    func saveTasks(_ tasks: [ActiveTask]) async throws {
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
    
    func loadTasks() async throws -> [ActiveTask] {
        let url = baseURL.appendingPathComponent("tasks")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([ActiveTask].self, from: data)
    }
    
    func addTask(_ task: ActiveTask) async throws {
        let url = baseURL.appendingPathComponent("task")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoded = try JSONEncoder().encode(task)
        let (_, response) = try await URLSession.shared.upload(for: request, from: encoded)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func addSubTask(parentId: UUID, title: String) async throws {
        let url = baseURL.appendingPathComponent("tasks/\(parentId)/subtasks")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["title": title]
        let encoded = try JSONEncoder().encode(payload)
        let (_, response) = try await URLSession.shared.upload(for: request, from: encoded)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

@MainActor
class TaskManager: ObservableObject, @unchecked Sendable {
    static let shared = TaskManager()  // Singleton instance
    
    @Published var tasks: [ActiveTask] = [] {
        didSet {
            Task {
                try? await saveTasksToStorage()
            }
        }
    }
    private var bannerWindow: NSWindow? {
        willSet {
            // Close and release the old window before creating a new one
            bannerWindow?.close()
        }
    }
    
    // Storage property that can be switched between local and remote
    private var storage: TaskStorage
    
    // Make init private to enforce singleton pattern
    private init() {
        // Initialize with local storage by default
        // Can be changed to remote storage: RemoteTaskStorage(baseURL: "https://api.example.com")
        self.storage = LocalTaskStorage()
        
        Task {
            await loadTasksFromStorage()
        }
        setupBannerWindow()
        updateBannerVisibility() // Show banner if there are loaded tasks
    }
    
    private func saveTasksToStorage() async throws {
        try await storage.saveTasks(tasks)
    }
    
    private func loadTasksFromStorage() async {
        do {
            let loadedTasks = try await storage.loadTasks()
            print("TaskManager loaded tasks: \(loadedTasks.count)")
            self.tasks = loadedTasks
            updateBannerVisibility()
        } catch {
            print("TaskManager failed to load tasks: \(error)")
        }
    }
    
    private func setupBannerWindow() {
        // Close any existing window first
        bannerWindow?.close()
        
        let bannerWindow = BannerWindow()
        let bannerView = BannerView()
            .environmentObject(self)
        let hostingView = NSHostingView(rootView: bannerView)
        hostingView.frame = bannerWindow.frame
        bannerWindow.contentView = hostingView
        self.bannerWindow = bannerWindow
        
        // Initially hide the window since there are no tasks
        bannerWindow.orderOut(nil)
    }
    
    func addTask(_ task: ActiveTask) {
        Task {
            try? await storage.addTask(task)
            DispatchQueue.main.async {
                self.tasks.append(task)
                self.updateBannerVisibility()
            }
        }
    }
    
    func removeTask(_ task: ActiveTask) {
        tasks.removeAll { $0.id == task.id }
        updateBannerVisibility()
    }
    
    private func updateBannerVisibility() {
        if self.tasks.isEmpty {
            self.bannerWindow?.orderOut(nil)
        } else {
            self.bannerWindow?.orderFront(nil)
            // Ensure window stays on top
            self.bannerWindow?.level = .statusBar
        }
    }
    
    func updateTask(_ task: ActiveTask, newTitle: String) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].title = newTitle
        }
    }
    
    func addSubTask(to parentTask: ActiveTask, title: String) async throws {
        print("Adding subtask '\(title)' to parent task '\(parentTask.title)' (id: \(parentTask.id))")
        let subTask = ActiveTask(title: title, parentId: parentTask.id)
        
        if let parentIndex = tasks.firstIndex(where: { $0.id == parentTask.id }) {
            tasks[parentIndex].subTasks.append(subTask)
            print("Added subtask. Parent now has \(tasks[parentIndex].subTasks.count) subtasks")
            try await saveTasksToStorage()
        } else {
            print("Failed to find parent task with id: \(parentTask.id)")
        }
    }
    
    // Update the main tasks array to only show root tasks
    var rootTasks: [ActiveTask] {
        tasks.filter { $0.parentId == nil }
    }
} 
