import Foundation

// First, make ActiveTask codable so we can save it
enum TaskStatus: String, Codable {
    case created
    case done
}

struct TaskItem: Identifiable, Codable {
    let id: Int64
    var title: String
    var startTime: Date
    var parentID: Int64?  // Changed from UUID? to Int64?
    var subTasks: [TaskItem]  // New field
    var status: TaskStatus  // New field
    var notes: [String]  // New field for storing notes
    var mode: TaskMode?  // Optional mode field - nil means shared across all modes
    
    enum CodingKeys: CodingKey {
        case id, title, startTime, parentID, subTasks, status, notes, mode
    }
    
    init(title: String, startTime: Date = Date(), parentId: Int64? = nil, id: Int64 = 0, mode: TaskMode? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.parentID = parentId
        self.subTasks = []
        self.status = .created
        self.notes = []
        self.mode = mode
    }
    
    // Add decoder init to handle legacy data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        parentID = try container.decodeIfPresent(Int64.self, forKey: .parentID)
        subTasks = try container.decode([TaskItem].self, forKey: .subTasks)
        // Default to .created if status is not present in the data
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .created
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []  // Default to empty array if notes not present
        mode = try container.decodeIfPresent(TaskMode.self, forKey: .mode)  // nil means shared across all modes
    }
}
