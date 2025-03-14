import Foundation
import AppKit
import SwiftUI

@MainActor
class TaskManager: ObservableObject, @unchecked Sendable {
    static let shared = TaskManager()  // Singleton instance
    
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var currentMode: TaskMode = .work  // Add current mode

    private var bannerWindow: NSWindow? {
        willSet {
            // Close and release the old window before creating a new one
            bannerWindow?.close()
        }
    }
    
    private let localStorage: LocalTaskStorage
    private let fileStorage: LocalTaskStorage
    private let remoteStorage: RemoteTaskStorage

    // Storage property that can be switched between local and remote
    private var storage: TaskStorage {
        switch StorageType.current {
        case .userDefaults:
            return localStorage
        case .file:
            return fileStorage
        case .remote:
            return remoteStorage
        }
    }
    
    // Make init private to enforce singleton pattern
    private init() {
        // Initialize with appropriate storage based on useRemote
        self.localStorage = LocalTaskStorage(storage: UserDefaultsPersistent(STORAGE_KEY))
        self.fileStorage = LocalTaskStorage(storage: FilePersistent())
        self.remoteStorage = RemoteTaskStorage()
        
        setupBannerWindow() // Setup window first
        
        Task {
            await loadTasksFromStorage()
        }
    }
    
    private func saveTasksToStorage() async throws {
        try await storage.saveTasks(tasks)
    }
    
    func loadTasksFromStorage() async {
        do {
            let loadedTasks = try await storage.loadTasks(mode: currentMode)
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
        
        // display immediately
        self.bannerWindow?.orderFront(nil)
        self.bannerWindow?.level = .statusBar
    }
    
    // Add function to switch mode
    func switchMode(_ newMode: TaskMode) {
        guard newMode != currentMode else { return }
        currentMode = newMode
        Task {
            await loadTasksFromStorage()
        }
    }
    
    func addTask(_ task: TaskItem) {
        Task {
            do {
                var newTask = task
                // Only set the mode if it's not explicitly set to shared
                if newTask.mode == nil {
                    newTask.mode = currentMode
                }
                let savedTask = try await storage.addTask(newTask)
                print("TaskManager added task: \(savedTask)")
                DispatchQueue.main.async {
                    if let parentId = savedTask.parentID {
                        // Use recursive approach to add task to its parent
                        func addToParent(in tasks: inout [TaskItem]) -> Bool {
                            for i in tasks.indices {
                                if tasks[i].id == parentId {
                                    tasks[i].subTasks.insert(savedTask, at: 0)
                                    return true
                                }
                                if addToParent(in: &tasks[i].subTasks) {
                                    return true
                                }
                            }
                            return false
                        }
                        _ = addToParent(in: &self.tasks)
                    } else {
                        // No parent ID, add to root tasks at the beginning
                        self.tasks.insert(savedTask, at: 0)
                    }
                    self.updateBannerVisibility()
                }
            } catch {
                print("Error adding task: \(error)")
            }
        }
    }
    
    func removeTask(_ task: TaskItem) {
        Task {
            do {
                try await storage.removeTask(taskId: task.id)
                await MainActor.run {
                    func removeFromParent(in tasks: inout [TaskItem]) -> Bool {
                        // First check at current level
                        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                            tasks.remove(at: index)
                            return true
                        }
                        // Then check in subtasks
                        for i in tasks.indices {
                            if removeFromParent(in: &tasks[i].subTasks) {
                                return true
                            }
                        }
                        return false
                    }
                    
                    _ = removeFromParent(in: &tasks)
                    updateBannerVisibility()
                }
            } catch {
                print("Error removing task: \(error)")
            }
        }
    }
    
    private func updateBannerVisibility() {
        print("updateBannerVisibility called: tasks.count=\(tasks.count), rootTasks.count=\(rootTasks.count)")
        if self.tasks.isEmpty && false {
            // NOTE: always show banner
            self.bannerWindow?.orderOut(nil)
        } else {
            self.bannerWindow?.orderFront(nil)
            // Ensure window stays on top
            self.bannerWindow?.level = .statusBar
        }
    }
    
    // Generic update method for tasks
    private func updateTaskGeneric(_ task: TaskItem, update: TaskUpdate) async throws {
        // Update in storage first
        try await storage.updateTask(taskId: task.id, update: update)
        
        // After successful storage update, update in memory
        func updateTaskRecursively(in tasks: inout [TaskItem], taskId: Int64, update: TaskUpdate) -> Bool {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                if let newTitle = update.title {
                    tasks[index].title = newTitle
                }
                if let newStatus = update.status {
                    tasks[index].status = newStatus
                }
                if let newNotes = update.notes {
                    tasks[index].notes = newNotes
                }
                return true
            }
            
            for i in tasks.indices {
                if updateTaskRecursively(in: &tasks[i].subTasks, taskId: taskId, update: update) {
                    return true
                }
            }
            return false
        }
        
        _ = updateTaskRecursively(in: &tasks, taskId: task.id, update: update)
        objectWillChange.send()
    }
    
    // Update task title using the generic update method
    func updateTask(_ task: TaskItem, newTitle: String) {
        Task {
            try? await updateTaskGeneric(task, update: TaskUpdate(title: newTitle))
        }
    }
    
    // Update task status using the generic update method
    func updateTaskStatus(_ task: TaskItem, newStatus: TaskStatus) async throws {
        try await updateTaskGeneric(task, update: TaskUpdate(status: newStatus))
    }
    
    private func updateSubTaskStatus(in subTasks: inout [TaskItem], taskId: Int64, newStatus: TaskStatus) -> Bool {
        return recursivelyModifyTask(in: &subTasks, taskId: taskId) { task in
            task.status = newStatus
        }
    }
    
    // Generic recursive helper function
    private func recursivelyModifyTask(in tasks: inout [TaskItem], taskId: Int64, operation: (inout TaskItem) -> Void) -> Bool {
        // Try to find and update the task in current level
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            operation(&tasks[index])
            return true
        }
        
        // Recursively search in deeper levels
        for index in tasks.indices {
            if recursivelyModifyTask(in: &tasks[index].subTasks, taskId: taskId, operation: operation) {
                return true
            }
        }
        
        return false
    }
    
    // Generic recursive finder function (read-only version)
    private func recursivelyFindTask(in tasks: [TaskItem], taskId: Int64) -> TaskItem? {
        if let task = tasks.first(where: { $0.id == taskId }) {
            return task
        }
        
        for task in tasks {
            if let found = recursivelyFindTask(in: task.subTasks, taskId: taskId) {
                return found
            }
        }
        
        return nil
    }

    private func findAdjacentTask(in tasks: [TaskItem], taskId: Int64, direction: MoveDirection) -> TaskItem? {
        // First try to find at current level
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            let newIndex = direction == .up ? index - 1 : index + 1
            if newIndex >= 0 && newIndex < tasks.count {
                return tasks[newIndex]
            }
            return nil
        }
        
        // If not found at current level, search in subtasks
        for task in tasks {
            if let found = findAdjacentTask(in: task.subTasks, taskId: taskId, direction: direction) {
                return found
            }
        }
        
        return nil
    }
    
    func moveTask(_ task: TaskItem, direction: MoveDirection) async {
        let adjacentTask = findAdjacentTask(in: tasks, taskId: task.id, direction: direction)

        // exchange
        try? await storage.exchangeOrder(aID: task.id, bID: adjacentTask?.id ?? 0)

        // update tasks array
        func moveTaskRecursively(in tasks: inout [TaskItem], id: Int64, direction: MoveDirection) -> Bool {
            // First try at current level
            for i in tasks.indices {
                if tasks[i].id == id {
                    let newIndex = direction == .up ? i - 1 : i + 1
                    if newIndex >= 0 && newIndex < tasks.count {
                        print("moveTaskRecursively: swapping tasks[\(i)]=\(tasks[i].title) with tasks[\(newIndex)]=\(tasks[newIndex].title)")
                        tasks.swapAt(i, newIndex)
                        return true
                    }
                    return false // Found but can't move (at boundary)
                }
            }
            
            // If not found at current level, try in each subtask
            for i in tasks.indices {
                if moveTaskRecursively(in: &tasks[i].subTasks, id: id, direction: direction) {
                    return true
                }
            }
            
            return false
        }

        _ = moveTaskRecursively(in: &tasks, id: task.id, direction: direction)
        objectWillChange.send()
    }
    
    // Update the main tasks array to only show root tasks
    var rootTasks: [TaskItem] {
        let roots = tasks.filter { task in
            task.parentID == nil || task.parentID == 0
        }
        print("rootTasks: tasks.count=\(tasks.count), root task count=\(roots.count)")
        return roots
    }
    
    func exportTasksToJSON() async throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(tasks)
    }
    
    func importTasksFromJSON(_ data: Data) async throws {
        let decoder = JSONDecoder()
        let importedTasks = try decoder.decode([TaskItem].self, from: data)
        self.tasks = importedTasks
        try await saveTasksToStorage()
    }
    
    func addNote(to task: TaskItem, note: String) {
        Task {
            do {
                try await storage.addTaskNote(taskId: task.id, note: note)
                
                // After successful storage update, update in memory
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[index].notes.append(note)
                } else {
                    // If not found in root tasks, search and update in subtasks
                    for parentIndex in tasks.indices {
                        if recursivelyModifyTask(in: &tasks[parentIndex].subTasks, taskId: task.id) { task in
                            task.notes.append(note)
                        } {
                            break
                        }
                    }
                }
                // Force a view update
                self.objectWillChange.send()
            } catch {
                print("Failed to add note: \(error)")
            }
        }
    }
    
    func editNote(in task: TaskItem, at index: Int, newText: String) {
        Task {
            do {
                try await storage.updateTaskNote(taskId: task.id, noteIndex: index, newText: newText)
                
                // After successful storage update, update in memory
                if let taskIndex = tasks.firstIndex(where: { $0.id == task.id }) {
                    guard index < tasks[taskIndex].notes.count else { return }
                    tasks[taskIndex].notes[index] = newText
                } else {
                    // If not found in root tasks, search and update in subtasks
                    for parentIndex in tasks.indices {
                        if recursivelyModifyTask(in: &tasks[parentIndex].subTasks, taskId: task.id) { task in
                            guard index < task.notes.count else { return }
                            task.notes[index] = newText
                        } {
                            break
                        }
                    }
                }
                // Force a view update
                self.objectWillChange.send()
            } catch {
                print("Failed to update note: \(error)")
            }
        }
    }
    
    private func editNoteInSubTask(in subTasks: inout [TaskItem], taskId: Int64, noteIndex: Int, newText: String) -> Bool {
        return recursivelyModifyTask(in: &subTasks, taskId: taskId) { task in
            guard noteIndex < task.notes.count else { return }
            task.notes[noteIndex] = newText
        }
    }
    
    private func addNoteToSubTask(in subTasks: inout [TaskItem], taskId: Int64, note: String) -> Bool {
        return recursivelyModifyTask(in: &subTasks, taskId: taskId) { task in
            task.notes.append(note)
        }
    }
    
    enum MoveDirection {
        case up
        case down
    }
} 
