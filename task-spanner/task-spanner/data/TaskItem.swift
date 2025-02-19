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
    var parentId: Int64?  // Changed from UUID? to Int64?
    var subTasks: [TaskItem]  // New field
    var status: TaskStatus  // New field
    var notes: [String]  // New field for storing notes
    
    enum CodingKeys: CodingKey {
        case id, title, startTime, parentId, subTasks, status, notes
    }
    
    init(title: String, startTime: Date = Date(), parentId: Int64? = nil, id: Int64 = 0) {
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
        subTasks = try container.decode([TaskItem].self, forKey: .subTasks)
        // Default to .created if status is not present in the data
        status = try container.decodeIfPresent(TaskStatus.self, forKey: .status) ?? .created
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []  // Default to empty array if notes not present
    }
}
