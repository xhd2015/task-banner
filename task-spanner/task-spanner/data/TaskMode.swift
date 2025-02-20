import Foundation

enum TaskMode: String, Codable, CaseIterable, Identifiable {
    case work = "work"
    case life = "life"
    case shared = ""  // Add empty string case for shared tasks
    
    var id: Self { self }
    
    // Custom decoder to handle nil as shared
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .shared
        } else {
            let value = try container.decode(String.self)
            switch value.uppercased() {
            case "WORK": self = .work
            case "LIFE": self = .life
            default: self = .shared
            }
        }
    }
} 