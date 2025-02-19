import Foundation

fileprivate let STORAGE_KEY = "savedTasks"
//fileprivate let STORAGE_KEY = "savedTasks-test"

// Local storage implementation
class LocalTaskStorage: TaskStorage {   
    func saveTasks(_ tasks: [TaskItem]) async throws {
        do {
            let encoded = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(encoded, forKey: STORAGE_KEY)
            print("Successfully saved tasks: \(tasks.count) root tasks")
        } catch {
            print("Error saving tasks: \(error)")
            throw error
        }
    }
    
    func loadTasks() async throws -> [TaskItem] {
        guard let savedTasks = UserDefaults.standard.data(forKey: STORAGE_KEY) else {
            print("No saved tasks found in UserDefaults")
            return []
        }
        
        do {
            let decodedTasks = try JSONDecoder().decode([TaskItem].self, from: savedTasks)
            print("Successfully loaded tasks: \(decodedTasks.count) root tasks")
            print("Tasks details: \(decodedTasks.map { "id: \($0.id), title: \($0.title), subTasks: \($0.subTasks.count)" })")
            return decodedTasks
        } catch {
            print("Error decoding tasks: \(error)")
            print("Raw data: \(String(data: savedTasks, encoding: .utf8) ?? "unable to convert to string")")
            return []
        }
    }
    
    private func findHighestTaskId() async throws -> Int64 {
        let tasks = try await loadTasks()
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
        var currentTasks = try await loadTasks()
        let highestId = try await findHighestTaskId()
        let newTask = TaskItem(title: task.title, startTime: task.startTime, parentId: task.parentId, id: highestId + 1)
        
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
        var currentTasks = try await loadTasks()
        
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
        var currentTasks = try await loadTasks()
        
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
        var currentTasks = try await loadTasks()
        
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
        var currentTasks = try await loadTasks()
        
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
        var currentTasks = try await loadTasks()
        
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
