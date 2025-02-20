import Foundation

fileprivate let STORAGE_KEY = "savedTasks"
//fileprivate let STORAGE_KEY = "savedTasks-test"

protocol DataPersistent<T> {
    associatedtype T
    func load() async throws -> T
    func save(_ data: T) async throws
}

class FilePersistent<T: Codable>: DataPersistent {
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let tasksFileName = "tasks.json"
    
    private var tasksFileURL: URL {
        return documentsPath.appendingPathComponent(tasksFileName)
    }

    func load() async throws -> T {
        guard fileManager.fileExists(atPath: tasksFileURL.path) else {
            throw NSError(domain: "FileStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        }
        let data = try Data(contentsOf: tasksFileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func save(_ data: T) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(data)
        try data.write(to: tasksFileURL)
    }
}

class UserDefaultsPersistent<T: Codable>: DataPersistent {
    private let userDefaults = UserDefaults.standard
    private let key: String

    init(_ key: String) {
        self.key = key
    }

    func load() async throws -> T {
        guard let data = userDefaults.data(forKey: key) else {
            throw NSError(domain: "UserDefaults", code: 404, userInfo: [NSLocalizedDescriptionKey: "Data not found"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func save(_ data: T) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(data)
        userDefaults.set(data, forKey: key)
    }
}

// Local storage implementation
class LocalTaskStorage: TaskStorage {   
    private let storage: any DataPersistent<[TaskItem]>
    
    init(storage: (any DataPersistent<[TaskItem]>)? = nil) {
        self.storage = storage ?? UserDefaultsPersistent<[TaskItem]>(STORAGE_KEY)
    }
    
    private func loadAllTasks() async throws -> [TaskItem] {
        return try await storage.load()
    }
    
    func loadTasks(mode: TaskMode?) async throws -> [TaskItem] {
        let allTasks = try await loadAllTasks()
        guard let mode = mode, mode != .shared else {
            return allTasks
        }
        
        // Filter tasks by mode recursively, including shared tasks (where mode is nil or empty)
        func filterByMode(_ tasks: [TaskItem]) -> [TaskItem] {
            return tasks.filter { task in
                task.mode == mode || task.mode == nil || task.mode == .shared  // Include both mode-specific and shared tasks
            }.map { task in
                var filteredTask = task
                filteredTask.subTasks = filterByMode(task.subTasks)
                return filteredTask
            }
        }
        
        return filterByMode(allTasks)
    }
    
    func saveTasks(_ tasks: [TaskItem]) async throws {
        try await storage.save(tasks)
    }
    
    private func findHighestTaskId() async throws -> Int64 {
        let tasks = try await loadTasks(mode: nil)
        var maxId: Int64 = 0
        
        func checkTask(_ task: TaskItem) {
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
    
    func addTask(_ task: TaskItem) async throws -> TaskItem {
        var currentTasks = try await loadTasks(mode: nil)
        let highestId = try await findHighestTaskId()
        let newTask = TaskItem(title: task.title, startTime: task.startTime, parentId: task.parentId, id: highestId + 1, mode: task.mode)
        
        if let parentId = task.parentId {
            // Find the parent task recursively and add the task as a subtask
            func addSubTaskRecursively(to tasks: inout [TaskItem], parentId: Int64) -> Bool {
                for index in tasks.indices {
                    if tasks[index].id == parentId {
                        tasks[index].subTasks.append(newTask)
                        return true
                    }
                    if addSubTaskRecursively(to: &tasks[index].subTasks, parentId: parentId) {
                        return true
                    }
                }
                return false
            }
            
            if !addSubTaskRecursively(to: &currentTasks, parentId: parentId) {
                print("Warning: Parent task with id \(parentId) not found")
            }
        } else {
            currentTasks.append(newTask)
        }
        
        try await saveTasks(currentTasks)
        return newTask
    }
    
    func updateTask(taskId: Int64, update: TaskUpdate) async throws {
        var currentTasks = try await loadTasks(mode: nil)
        
        func updateTaskRecursively(in tasks: inout [TaskItem]) -> Bool {
            for index in tasks.indices {
                if tasks[index].id == taskId {
                    if let newTitle = update.title {
                        tasks[index].title = newTitle
                    }
                    if let newStatus = update.status {
                        tasks[index].status = newStatus
                    }
                    if let newNotes = update.notes {
                        tasks[index].notes = newNotes
                    }
                    if let newMode = update.mode {
                        tasks[index].mode = newMode
                    }
                    return true
                }
                if updateTaskRecursively(in: &tasks[index].subTasks) {
                    return true
                }
            }
            return false
        }
        
        if updateTaskRecursively(in: &currentTasks) {
            try await saveTasks(currentTasks)
        } else {
            throw NSError(domain: "TaskStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
    }
    
    func removeTask(taskId: Int64) async throws {
        var currentTasks = try await loadTasks(mode: nil)
        
        func removeTaskRecursively(from tasks: inout [TaskItem]) -> Bool {
            // First check at current level
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks.remove(at: index)
                return true
            }
            
            // Then check in subtasks
            for index in tasks.indices {
                if removeTaskRecursively(from: &tasks[index].subTasks) {
                    return true
                }
            }
            return false
        }
        
        if removeTaskRecursively(from: &currentTasks) {
            try await saveTasks(currentTasks)
        } else {
            throw NSError(domain: "TaskStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
    }
        func exchangeOrder(aID: Int64, bID: Int64) async throws {
        var currentTasks = try await loadTasks(mode: nil)
        
        func exchangeTasksRecursively(in tasks: inout [TaskItem]) -> Bool {
            // First check at current level
            if let aIndex = tasks.firstIndex(where: { $0.id == aID }),
               let bIndex = tasks.firstIndex(where: { $0.id == bID }) {
                tasks.swapAt(aIndex, bIndex)
                return true
            }
            
            // Then check in subtasks
            for index in tasks.indices {
                if exchangeTasksRecursively(in: &tasks[index].subTasks) {
                    return true
                }
            }
            return false
        }
        
        if exchangeTasksRecursively(in: &currentTasks) {
            try await saveTasks(currentTasks)
        } else {
            throw NSError(domain: "TaskStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Tasks not found or not at same level"])
        }
    }
    
    func addTaskNote(taskId: Int64, note: String) async throws {
        var currentTasks = try await loadTasks(mode: nil)
        
        func addNoteRecursively(in tasks: inout [TaskItem]) -> Bool {
            // First check at current level
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].notes.append(note)
                return true
            }
            
            // Then check in subtasks
            for index in tasks.indices {
                if addNoteRecursively(in: &tasks[index].subTasks) {
                    return true
                }
            }
            return false
        }
        
        if addNoteRecursively(in: &currentTasks) {
            try await saveTasks(currentTasks)
        } else {
            throw NSError(domain: "TaskStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
        }
    }
    
    func updateTaskNote(taskId: Int64, noteIndex: Int, newText: String) async throws {
        var currentTasks = try await loadTasks(mode: nil)
        
        func updateNoteRecursively(in tasks: inout [TaskItem]) -> Bool {
            // First check at current level
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                guard noteIndex < tasks[index].notes.count else {
                    return false
                }
                tasks[index].notes[noteIndex] = newText
                return true
            }
            
            // Then check in subtasks
            for index in tasks.indices {
                if updateNoteRecursively(in: &tasks[index].subTasks) {
                    return true
                }
            }
            return false
        }
        
        if updateNoteRecursively(in: &currentTasks) {
            try await saveTasks(currentTasks)
        } else {
            throw NSError(domain: "TaskStorage", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task or note not found"])
        }
    }
}
