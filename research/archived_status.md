# Research Report: Adding Archived Status to Task Management System

## Current Status Implementation

The task management system currently has two statuses:
1. `created` (default status when task is first created)
2. `done` (task is marked as completed)

The status is implemented across multiple layers:

### 1. Data Model
- Proto definition: `proto/task.proto`
- Swift model: `task-spanner/task-spanner/data/TaskItem.swift`
- Go model: `server/model/task.go`

### 2. Storage Layer
- Local storage: `task-spanner/task-spanner/data/LocalTaskStorage.swift`
- Server storage: 
  - SQLite: `server/dao/sqlite/repository.go`
  - MySQL: `server/dao/mysql/repository.go`

### 3. UI Implementation
- Main task list: `task-spanner/task-spanner/banner/BannerItemView.swift`
- Task detail view: `task-spanner/task-spanner/detail/TaskDetailView.swift`

## Required Changes

### 1. Data Model Updates
```go
// Current
enum TaskStatus {
  TASK_STATUS_CREATED = 0;
  TASK_STATUS_DONE = 1;
}

// Proposed
enum TaskStatus {
  TASK_STATUS_CREATED = 0;
  TASK_STATUS_DONE = 1;
  TASK_STATUS_ARCHIVED = 2;
}
```

### 2. UI Changes (MacOS App Only)
- Add archived status toggle in task detail view
- Update task list view to handle archived status display
- Add filtering options for archived tasks

#### Filtering Implementation Details
1. Modify the state variable in `BannerView.swift` to use an enum instead of boolean:
```swift
// Replace this:
@State private var showOnlyUnfinished: Bool = true

// With this:
enum TaskViewMode {
    case unfinished  // Show only unfinished tasks (default)
    case all         // Show all active tasks
    case archived    // Show only archived tasks
}
@State private var viewMode: TaskViewMode = .unfinished
```

2. Update `filteredTasks` computed property:
```swift
var filteredTasks: [TaskItem] {
    switch viewMode {
    case .unfinished:
        return taskManager.rootTasks.filter { task in
            filterUnfinishedTasks(task) || recentlyFinishedTasks.contains(task.id)
        }
    case .all:
        return taskManager.rootTasks.filter { task in
            task.status != .archived  // Filter out archived tasks
        }
    case .archived:
        return taskManager.rootTasks.filter { task in
            task.status == .archived
        }
    }
}
```

3. Update `filterUnfinishedTasks` function:
```swift
private func filterUnfinishedTasks(_ task: TaskItem) -> Bool {
    if task.status == .archived {
        return false
    }
    if task.status == .created || recentlyFinishedTasks.contains(task.id) {
        return true
    }
    return task.subTasks.contains { filterUnfinishedTasks($0) }
}
```

4. Update task item display in `BannerItemView.swift`:
```swift
Text(task.title)
    .foregroundColor(
        task.status == .archived ? .gray :
        task.status == .done || recentlyFinishedTasks.contains(task.id) ? .secondary : .primary
    )
    .lineLimit(1)
    .strikethrough(task.status == .done || recentlyFinishedTasks.contains(task.id))
    .italic(task.status == .archived)
```

5. Modify the `BannerTopBar.swift` to use a 3-state toggle button:
```swift
// Replace current toggle code:
IconButton(
    systemName: showOnlyUnfinished ? "checklist.unchecked" : "checklist",
    action: { showOnlyUnfinished.toggle() }
)

// With this:
IconButton(
    systemName: {
        switch viewMode {
        case .unfinished: return "checklist.unchecked"  // Current icon for unfinished tasks
        case .all: return "checklist"                   // Current icon for all tasks
        case .archived: return "archivebox"             // New icon for archived tasks
        }
    }(),
    action: {
        // Cycle through the three modes
        switch viewMode {
        case .unfinished: viewMode = .all
        case .all: viewMode = .archived
        case .archived: viewMode = .unfinished
        }
    }
)
```

#### UI Changes (ASCII Chart)
```
Current UI Toggle:
+------------------------+
|  [☐/☑] [Work] [Life]   |  <- Toggle between checklist.unchecked/checklist
+------------------------+
|  [ ] Task 1           |
|  [x] Task 2           |
|  [ ] Task 3           |
+------------------------+

Proposed UI Toggle (3-state):
+------------------------+
|  [⊠/☑/🗃️] [Work] [Life] |  <- Cycle through checklist.unchecked/checklist/archivebox
+------------------------+
|  [ ] Task 1           |
|  [x] Task 2           |
|  [ ] Task 3           |
+------------------------+

Mode Transitions:
⊠ (unfinished) -> ☑ (all) -> 🗃️ (archived) -> ⊠ (unfinished)

Task Display:
- Normal task:    [ ] Task title
- Done task:      [x] Task title (strikethrough)
- Archived task:  [ ] Task title (gray, italic)
```

### 3. Storage Layer
- No schema changes needed as status is stored as string/VARCHAR
- Update status validation in storage layer

## Implementation Considerations

### 1. Data Migration
- Existing tasks will need to be migrated to handle the new status
- Default value for existing tasks should be 'created'

### 2. UI/UX Considerations
- Archived tasks should be visually distinct
- Consider adding a filter to show/hide archived tasks
- Archived tasks should not appear in active task lists by default

### 3. Business Logic
- Archived tasks should not be editable
- Archived tasks should not appear in task counts
- Archived tasks should be preserved for historical reference

## Technical Impact

### 1. Backward Compatibility
- Proto changes require regeneration of client code
- Existing task data remains valid

### 2. Performance Impact
- Minimal impact as status is a simple enum
- No additional storage requirements
- No impact on query performance

### 3. Testing Requirements
- Unit tests for new status handling
- Integration tests for archived task behavior
- UI tests for archived task display and interactions

## Reference Links
1. [Protocol Buffers Documentation](https://developers.google.com/protocol-buffers)
2. [Swift Codable Protocol](https://developer.apple.com/documentation/swift/codable)
3. [SQLite Data Types](https://www.sqlite.org/datatype3.html)
4. [MySQL ENUM Type](https://dev.mysql.com/doc/refman/8.0/en/enum.html) 