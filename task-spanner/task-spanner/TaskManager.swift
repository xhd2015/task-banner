import Foundation
import AppKit
import SwiftUI

// First, make ActiveTask codable so we can save it
enum TaskStatus: String, Codable {
    case created
    case done
}

struct ActiveTask: Identifiable, Codable {
    let id: Int64
    var title: String
    var startTime: Date
    var parentId: Int64?  // Changed from UUID? to Int64?
    var subTasks: [ActiveTask]  // New field
    var status: TaskStatus  // New field
    var notes: [String]  // New field for storing notes
    
    enum CodingKeys: CodingKey {
        case id, title, startTime, parentId, subTasks, status, notes
    }
    
    init(title: String, startTime: Date = Date(), parentId: Int64? = nil, id: Int64) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.parentId = parentId
        self.subTasks = []
        self.status = .created
        self.notes = []
    }
    
    // Add decoder init to handle legacy data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        parentId = try container.decodeIfPresent(Int64.self, forKey: .parentId)
        subTasks = try container.decode([ActiveTask].self, forKey: .subTasks)
        // Default to .created if status is not present in the data
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .created
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []  // Default to empty array if notes not present
    }
}

// Define protocol for data storage
protocol TaskStorage {
    func saveTasks(_ tasks: [ActiveTask]) async throws
    func loadTasks() async throws -> [ActiveTask]
    func addTask(_ task: ActiveTask) async throws
    func addSubTask(parentId: Int64, title: String) async throws
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
    
    func addSubTask(parentId: Int64, title: String) async throws {
        var currentTasks = try await loadTasks()
        let subTask = ActiveTask(title: title, parentId: parentId, id: 0)
        
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
    
    func addSubTask(parentId: Int64, title: String) async throws {
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
    
    // Add helper method to find highest task ID
    private func findHighestTaskId() -> Int64 {
        var maxId: Int64 = 0
        
        func checkTask(_ task: ActiveTask) {
            maxId = max(maxId, task.id)
            for subtask in task.subTasks {
                checkTask(subtask)
            }
        }
        
        for task in tasks {
            checkTask(task)
        }
        
        return maxId
    }
    
    func addTask(_ task: ActiveTask) {
        Task {
            // Create new task with sequential ID
            let highestId = findHighestTaskId()
            let newTask = ActiveTask(title: task.title, startTime: task.startTime, parentId: task.parentId, id: highestId + 1)
            
            try? await storage.addTask(newTask)
            DispatchQueue.main.async {
                self.tasks.append(newTask)
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
        // First try to find and update in root tasks
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].title = newTitle
            return
        }
        
        // If not found in root tasks, search and update in subtasks
        for parentIndex in tasks.indices {
            if updateSubTask(in: &tasks[parentIndex].subTasks, taskId: task.id, newTitle: newTitle) {
                // Force a view update by reassigning tasks
                self.objectWillChange.send()
                break
            }
        }
    }
    
    private func updateSubTask(in subTasks: inout [ActiveTask], taskId: Int64, newTitle: String) -> Bool {
        // Try to find and update the task in current level
        if let index = subTasks.firstIndex(where: { $0.id == taskId }) {
            subTasks[index].title = newTitle
            return true
        }
        
        // Recursively search in deeper levels
        for index in subTasks.indices {
            if updateSubTask(in: &subTasks[index].subTasks, taskId: taskId, newTitle: newTitle) {
                return true
            }
        }
        
        return false
    }
    
    func addSubTask(to parentTask: ActiveTask, title: String) async throws {
        print("Adding subtask '\(title)' to parent task '\(parentTask.title)' (id: \(parentTask.id))")
        let highestId = findHighestTaskId()
        let subTask = ActiveTask(title: title, parentId: parentTask.id, id: highestId + 1)
        
        // Try to find and update the task at any nesting level
        if addSubTaskToParent(subTask, parentId: parentTask.id, in: &tasks) {
            print("Added subtask to parent task '\(parentTask.title)'")
            try await saveTasksToStorage()
        } else {
            print("Failed to find parent task with id: \(parentTask.id)")
        }
    }
    
    private func addSubTaskToParent(_ subTask: ActiveTask, parentId: Int64, in tasks: inout [ActiveTask]) -> Bool {
        // Try to find the parent task in current level
        if let index = tasks.firstIndex(where: { $0.id == parentId }) {
            tasks[index].subTasks.append(subTask)
            return true
        }
        
        // Recursively search in deeper levels
        for index in tasks.indices {
            if addSubTaskToParent(subTask, parentId: parentId, in: &tasks[index].subTasks) {
                return true
            }
        }
        
        return false
    }
    
    // Update the main tasks array to only show root tasks
    var rootTasks: [ActiveTask] {
        tasks.filter { $0.parentId == nil }
    }
    
    func exportTasksToJSON() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(tasks)
    }
    
    func importTasksFromJSON(_ data: Data) async throws {
        let decoder = JSONDecoder()
        let importedTasks = try decoder.decode([ActiveTask].self, from: data)
        self.tasks = importedTasks
        try await saveTasksToStorage()
    }
    
    func updateTaskStatus(_ task: ActiveTask, newStatus: TaskStatus) {
        // First try to find and update in root tasks
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = newStatus
            return
        }
        
        // If not found in root tasks, search and update in subtasks
        for parentIndex in tasks.indices {
            if updateSubTaskStatus(in: &tasks[parentIndex].subTasks, taskId: task.id, newStatus: newStatus) {
                // Force a view update by reassigning tasks
                self.objectWillChange.send()
                break
            }
        }
    }
    
    private func updateSubTaskStatus(in subTasks: inout [ActiveTask], taskId: Int64, newStatus: TaskStatus) -> Bool {
        // Try to find and update the task in current level
        if let index = subTasks.firstIndex(where: { $0.id == taskId }) {
            subTasks[index].status = newStatus
            return true
        }
        
        // Recursively search in deeper levels
        for index in subTasks.indices {
            if updateSubTaskStatus(in: &subTasks[index].subTasks, taskId: taskId, newStatus: newStatus) {
                return true
            }
        }
        
        return false
    }
    
    func moveTask(_ task: ActiveTask, direction: MoveDirection) {
        if let parentId = task.parentId {
            // Move within subtasks
            if let parentIndex = tasks.firstIndex(where: { $0.id == parentId }) {
                moveSubTask(in: &tasks[parentIndex].subTasks, taskId: task.id, direction: direction)
                objectWillChange.send()
            }
        } else {
            // Move within root tasks
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                let newIndex = direction == .up ? index - 1 : index + 1
                if newIndex >= 0 && newIndex < tasks.count {
                    tasks.swapAt(index, newIndex)
                }
            }
        }
    }
    
    private func moveSubTask(in subTasks: inout [ActiveTask], taskId: Int64, direction: MoveDirection) -> Bool {
        if let index = subTasks.firstIndex(where: { $0.id == taskId }) {
            let newIndex = direction == .up ? index - 1 : index + 1
            if newIndex >= 0 && newIndex < subTasks.count {
                subTasks.swapAt(index, newIndex)
                return true
            }
        }
        
        // Try to find in deeper levels
        for i in subTasks.indices {
            if moveSubTask(in: &subTasks[i].subTasks, taskId: taskId, direction: direction) {
                return true
            }
        }
        
        return false
    }
    
    func addNote(to task: ActiveTask, note: String) {
        // First try to find and update in root tasks
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].notes.append(note)
            return
        }
        
        // If not found in root tasks, search and update in subtasks
        for parentIndex in tasks.indices {
            if addNoteToSubTask(in: &tasks[parentIndex].subTasks, taskId: task.id, note: note) {
                // Force a view update
                self.objectWillChange.send()
                break
            }
        }
    }
    
    func editNote(in task: ActiveTask, at index: Int, newText: String) {
        // First try to find and update in root tasks
        if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
            guard index < tasks[taskIndex].notes.count else { return }
            tasks[taskIndex].notes[index] = newText
            return
        }
        
        // If not found in root tasks, search and update in subtasks
        for parentIndex in tasks.indices {
            if editNoteInSubTask(in: &tasks[parentIndex].subTasks, taskId: task.id, noteIndex: index, newText: newText) {
                // Force a view update
                self.objectWillChange.send()
                break
            }
        }
    }
    
    private func editNoteInSubTask(in subTasks: inout [ActiveTask], taskId: Int64, noteIndex: Int, newText: String) -> Bool {
        // Try to find and update the task in current level
        if let index = subTasks.firstIndex(where: { $0.id == taskId }) {
            guard noteIndex < subTasks[index].notes.count else { return false }
            subTasks[index].notes[noteIndex] = newText
            return true
        }
        
        // Recursively search in deeper levels
        for index in subTasks.indices {
            if editNoteInSubTask(in: &subTasks[index].subTasks, taskId: taskId, noteIndex: noteIndex, newText: newText) {
                return true
            }
        }
        
        return false
    }
    
    private func addNoteToSubTask(in subTasks: inout [ActiveTask], taskId: Int64, note: String) -> Bool {
        // Try to find and update the task in current level
        if let index = subTasks.firstIndex(where: { $0.id == taskId }) {
            subTasks[index].notes.append(note)
            return true
        }
        
        // Recursively search in deeper levels
        for index in subTasks.indices {
            if addNoteToSubTask(in: &subTasks[index].subTasks, taskId: taskId, note: note) {
                return true
            }
        }
        
        return false
    }
    
    enum MoveDirection {
        case up
        case down
    }
} 
