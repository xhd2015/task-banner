import Foundation

// MARK: - Models
enum TaskStatus: Int, Codable {
    case created = 0
    case done = 1
}

struct Task: Codable, Identifiable {
    let id: Int64
    var title: String
    var startTime: Date
    var parentId: Int64?
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
    
    func getTask(id: Int64) throws -> Task? {
        let tasks = try loadTasks()
        return findTask(id: id, in: tasks)
    }
    
    private func findTask(id: Int64, in tasks: [Task]) -> Task? {
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
    
    func createTask(title: String, parentId: Int64? = nil) throws -> Task {
        var tasks = try loadTasks()
        let newTask = Task(
            id: Int64.random(in: 1...Int64.max),
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
    
    func updateTask(id: Int64, title: String? = nil, status: TaskStatus? = nil) throws -> Task? {
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
    
    func addNote(taskId: Int64, note: String) throws -> Task? {
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
    
    func deleteTask(id: Int64) throws {
        var tasks = try loadTasks()
        tasks = deleteTaskRecursively(tasks, taskId: id)
        try saveTasks(tasks)
    }
    
    // MARK: - Helper Methods
    private func updateTasksRecursively(_ tasks: [Task], taskId: Int64, update: (Task) -> Task) -> [Task] {
        return tasks.map { task in
            if task.id == taskId {
                return update(task)
            }
            var updatedTask = task
            updatedTask.subTasks = updateTasksRecursively(task.subTasks, taskId: taskId, update: update)
            return updatedTask
        }
    }
    
    private func updateTasksRecursively(_ tasks: [Task], parentId: Int64, update: (Task) -> Task) -> [Task] {
        return tasks.map { task in
            if task.id == parentId {
                return update(task)
            }
            var updatedTask = task
            updatedTask.subTasks = updateTasksRecursively(task.subTasks, parentId: parentId, update: update)
            return updatedTask
        }
    }
    
    private func deleteTaskRecursively(_ tasks: [Task], taskId: Int64) -> [Task] {
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
