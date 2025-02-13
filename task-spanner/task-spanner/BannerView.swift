import SwiftUI

// Add this struct near other route-related types
struct RouteParams: Equatable {
    var taskId: UUID?
    
    static func == (lhs: RouteParams, rhs: RouteParams) -> Bool {
        lhs.taskId == rhs.taskId
    }
}

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isDragging: Bool = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingText: String = ""
    @State private var showOnlyUnfinished: Bool = true
    @State private var recentlyFinishedTasks: Set<UUID> = []
    @State private var mode: TaskMode = .work
    @State private var isCollapsed: Bool = false
    @State private var routePath: RoutePath = .list
    @State private var routeParams: RouteParams = RouteParams()
    @FocusState private var isEditing: Bool
    
    var filteredTasks: [ActiveTask] {
        showOnlyUnfinished ? 
            taskManager.rootTasks.filter { task in
                filterUnfinishedTasks(task) || recentlyFinishedTasks.contains(task.id)
            } :
            taskManager.rootTasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                if routePath == .detail {
                    Button(action: { 
                        routePath = .list
                        routeParams = RouteParams()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing)
                } else {
                    Button(action: { showOnlyUnfinished.toggle() }) {
                        Image(systemName: showOnlyUnfinished ? "checklist.unchecked" : "checklist")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing)
                }
                
                if routePath == .list {
                    ModeSwitcher(mode: $mode)
                } else {
                    Text("Task Details")
                        .foregroundColor(.primary)
                        .font(.subheadline)
                }
                
                Spacer()
                
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                    }
                }) {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if !isCollapsed {
                Group {
                    if routePath == .detail {
                        if let taskId = routeParams.taskId {
                            if let task = findTask(id: taskId) {
                                TaskDetailView(task: task)
                                    .transition(.move(edge: .trailing))
                            } else {
                                Text("Task not found")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Invalid task ID")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 0) {
                                ForEach(filteredTasks) { task in
                                    TaskItemWithSubtasks(task: task, 
                                        editingTaskId: $editingTaskId, 
                                        editingText: $editingText, 
                                        isEditing: $isEditing,
                                        selectedTaskId: .constant(nil),
                                        onTaskSelect: { taskId in
                                            withAnimation {
                                                routePath = .detail
                                                routeParams = RouteParams(taskId: taskId)
                                            }
                                        })
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .transition(.move(edge: .leading))
                    }
                }
            }
        }
        .environment(\.showOnlyUnfinished, showOnlyUnfinished)
        .frame(maxWidth: 400, minHeight: isCollapsed ? 1 : 300, maxHeight: isCollapsed ? 50 : 600)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal)
        .opacity(isDragging ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .animation(.easeInOut(duration: 0.2), value: routePath)
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onAppear {
            print("BannerView appeared with route: \(routePath), params: \(routeParams)")
        }
        .onChange(of: routePath) { newPath in
            print("Route changed to: \(newPath), params: \(routeParams)")
        }
        .onChange(of: routeParams) { newParams in
            print("Route params changed: \(newParams)")
        }
    }
    
    private func findTask(id: UUID) -> ActiveTask? {
        func search(in tasks: [ActiveTask]) -> ActiveTask? {
            for task in tasks {
                if task.id == id {
                    return task
                }
                if let found = search(in: task.subTasks) {
                    return found
                }
            }
            return nil
        }
        return search(in: taskManager.rootTasks)
    }
    
    // Recursively filter tasks and their subtasks
    private func filterUnfinishedTasks(_ task: ActiveTask) -> Bool {
        if task.status == .created || recentlyFinishedTasks.contains(task.id) {
            return true
        }
        return task.subTasks.contains { filterUnfinishedTasks($0) }
    }
}

private struct ModeSwitcher: View {
    @Binding var mode: TaskMode
    
    var body: some View {
        Menu {
            ForEach(TaskMode.allCases) { mode in
                Button(action: { self.mode = mode }) {
                    HStack {
                        Text(mode.rawValue)
                        if self.mode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(mode.rawValue)
                    .foregroundColor(.primary)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption2)
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }
}

private struct TaskItemWithSubtasks: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    @Binding var editingTaskId: UUID?
    @Binding var editingText: String
    @FocusState.Binding var isEditing: Bool
    @Environment(\.showOnlyUnfinished) private var showOnlyUnfinished
    let indentLevel: Int
    @State private var recentlyFinishedTasks: Set<UUID> = []
    @Binding var selectedTaskId: UUID?
    let onTaskSelect: (UUID) -> Void
    
    init(task: ActiveTask, editingTaskId: Binding<UUID?>, editingText: Binding<String>, isEditing: FocusState<Bool>.Binding, indentLevel: Int = 0, selectedTaskId: Binding<UUID?>, onTaskSelect: @escaping (UUID) -> Void) {
        self.task = task
        self._editingTaskId = editingTaskId
        self._editingText = editingText
        self._isEditing = isEditing
        self.indentLevel = indentLevel
        self._selectedTaskId = selectedTaskId
        self.onTaskSelect = onTaskSelect
    }
    
    var filteredSubTasks: [ActiveTask] {
        showOnlyUnfinished ? 
            task.subTasks.filter { task in
                filterUnfinishedTasks(task) || recentlyFinishedTasks.contains(task.id)
            } :
            task.subTasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            BannerItemView(task: task, 
                editingTaskId: $editingTaskId, 
                editingText: $editingText, 
                isEditing: $isEditing, 
                indentLevel: indentLevel,
                onTaskSelect: onTaskSelect,
                recentlyFinishedTasks: $recentlyFinishedTasks)
            
            ForEach(filteredSubTasks) { subTask in
                TaskItemWithSubtasks(task: subTask, 
                    editingTaskId: $editingTaskId, 
                    editingText: $editingText, 
                    isEditing: $isEditing, 
                    indentLevel: indentLevel + 1,
                    selectedTaskId: $selectedTaskId,
                    onTaskSelect: onTaskSelect)
            }
        }
    }
    
    // Recursively filter tasks and their subtasks
    private func filterUnfinishedTasks(_ task: ActiveTask) -> Bool {
        if task.status == .created || recentlyFinishedTasks.contains(task.id) {
            return true
        }
        return task.subTasks.contains { filterUnfinishedTasks($0) }
    }
}

// Create an environment key for the filter state
private struct ShowOnlyUnfinishedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var showOnlyUnfinished: Bool {
        get { self[ShowOnlyUnfinishedKey.self] }
        set { self[ShowOnlyUnfinishedKey.self] = newValue }
    }
}

extension View {
    func delayedDisappearance(taskId: UUID, isFinished: Bool, delay: Double = 5.0, onFinished: @escaping (UUID) -> Void) -> some View {
        self.onChange(of: isFinished) { finished in
            if finished {
                onFinished(taskId)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    onFinished(taskId)
                }
            }
        }
    }

    func debugPrint(_ items: Any...) -> some View {
        #if DEBUG
        for item in items {
            print(item)
        }
        #endif
        return self
    }
}

// Add this enum at the bottom of the file
enum TaskMode: String, CaseIterable, Identifiable {
    case work = "WORK"
    case life = "LIFE"
    
    var id: Self { self }
}

// Add this enum at the bottom of the file, near other enums
enum RoutePath {
    case list
    case detail
} 
