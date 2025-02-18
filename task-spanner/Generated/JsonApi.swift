import Foundation

// MARK: - Models
enum TaskStatus: Int, Codable {
    case created = 0
    case done = 1
}

struct Task: Codable, Identifiable {
    let id: String
    var title: String
    var startTime: Date
    var parentId: String?
    var subTasks: [Task]
    var status: TaskStatus
    var notes: [String]
}

// MARK: - JsonApi
class JsonApi {
    private let fileManager = FileManager.default
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let tasksFileName = "tasks.json"
    
    private var tasksFileURL: URL {
        return documentsPath.appendingPathComponent(tasksFileName)
    }
    
    // MARK: - Private Methods
    private func loadTasks() throws -> [Task] {
        guard fileManager.fileExists(atPath: tasksFileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: tasksFileURL)
        return try JSONDecoder().decode([Task].self, from: data)
    }
    
    private func saveTasks(_ tasks: [Task]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(tasks)
        try data.write(to: tasksFileURL)
    }
    
    // MARK: - Public API
    func listTasks() throws -> [Task] {
        return try loadTasks()
    }
    
    func getTask(id: String) throws -> Task? {
        let tasks = try loadTasks()
        return findTask(id: id, in: tasks)
    }
    
    private func findTask(id: String, in tasks: [Task]) -> Task? {
        for task in tasks {
            if task.id == id {
                return task
            }
            if let found = findTask(id: id, in: task.subTasks) {
                return found
            }
        }
        return nil
    }
    
    func createTask(title: String, parentId: String? = nil) throws -> Task {
        var tasks = try loadTasks()
        let newTask = Task(
            id: UUID().uuidString,
            title: title,
            startTime: Date(),
            parentId: parentId,
            subTasks: [],
            status: .created,
            notes: []
        )
        
        if let parentId = parentId {
            tasks = updateTasksRecursively(tasks, parentId: parentId) { parent in
                var updatedParent = parent
                updatedParent.subTasks.append(newTask)
                return updatedParent
            }
        } else {
            tasks.append(newTask)
        }
        
        try saveTasks(tasks)
        return newTask
    }
    
    func updateTask(id: String, title: String? = nil, status: TaskStatus? = nil) throws -> Task? {
        var tasks = try loadTasks()
        var updatedTask: Task?
        
        tasks = updateTasksRecursively(tasks, taskId: id) { task in
            var updated = task
            if let newTitle = title {
                updated.title = newTitle
            }
            if let newStatus = status {
                updated.status = newStatus
            }
            updatedTask = updated
            return updated
        }
        
        try saveTasks(tasks)
        return updatedTask
    }
    
    func addNote(taskId: String, note: String) throws -> Task? {
        var tasks = try loadTasks()
        var updatedTask: Task?
        
        tasks = updateTasksRecursively(tasks, taskId: taskId) { task in
            var updated = task
            updated.notes.append(note)
            updatedTask = updated
            return updated
        }
        
        try saveTasks(tasks)
        return updatedTask
    }
    
    func deleteTask(id: String) throws {
        var tasks = try loadTasks()
        tasks = deleteTaskRecursively(tasks, taskId: id)
        try saveTasks(tasks)
    }
    
    // MARK: - Helper Methods
    private func updateTasksRecursively(_ tasks: [Task], taskId: String, update: (Task) -> Task) -> [Task] {
        return tasks.map { task in
            if task.id == taskId {
                return update(task)
            }
            var updatedTask = task
            updatedTask.subTasks = updateTasksRecursively(task.subTasks, taskId: taskId, update: update)
            return updatedTask
        }
    }
    
    private func updateTasksRecursively(_ tasks: [Task], parentId: String, update: (Task) -> Task) -> [Task] {
        return tasks.map { task in
            if task.id == parentId {
                return update(task)
            }
            var updatedTask = task
            updatedTask.subTasks = updateTasksRecursively(task.subTasks, parentId: parentId, update: update)
            return updatedTask
        }
    }
    
    private func deleteTaskRecursively(_ tasks: [Task], taskId: String) -> [Task] {
        var updatedTasks = tasks
        if let index = updatedTasks.firstIndex(where: { $0.id == taskId }) {
            updatedTasks.remove(at: index)
            return updatedTasks
        }
        
        return updatedTasks.map { task in
            var updatedTask = task
            updatedTask.subTasks = deleteTaskRecursively(task.subTasks, taskId: taskId)
            return updatedTask
        }
    }
}
