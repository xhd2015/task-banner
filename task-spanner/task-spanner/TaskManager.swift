import Foundation
import AppKit
import SwiftUI

// First, make ActiveTask codable so we can save it
struct ActiveTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var startTime: Date
    
    init(title: String, startTime: Date = Date()) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
    }
}

// Define protocol for data storage
protocol TaskStorage {
    func saveTasks(_ tasks: [ActiveTask]) async throws
    func loadTasks() async throws -> [ActiveTask]
    func addTask(_ task: ActiveTask) async throws
}

// Local storage implementation
class LocalTaskStorage: TaskStorage {
    func saveTasks(_ tasks: [ActiveTask]) async throws {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "savedTasks")
        }
    }
    
    func loadTasks() async throws -> [ActiveTask] {
        guard let savedTasks = UserDefaults.standard.data(forKey: "savedTasks"),
              let decodedTasks = try? JSONDecoder().decode([ActiveTask].self, from: savedTasks) else {
            return []
        }
        return decodedTasks
    }
    
    func addTask(_ task: ActiveTask) async throws {
        var currentTasks = try await loadTasks()
        currentTasks.append(task)
        try await saveTasks(currentTasks)
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
        if let loadedTasks = try? await storage.loadTasks() {
            self.tasks = loadedTasks
            updateBannerVisibility()
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
} 