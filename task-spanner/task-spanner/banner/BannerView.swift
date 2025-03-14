import SwiftUI

// Add this struct near other route-related types
struct RouteParams: Equatable {
    var taskId: Int64?
    
    static func == (lhs: RouteParams, rhs: RouteParams) -> Bool {
        lhs.taskId == rhs.taskId
    }
}

// Add this struct near other route-related types
struct RouteState: Equatable {
    var path: RoutePath
    var params: RouteParams
}

// Add this class near other route-related types
class RouteManager: ObservableObject {
    @Published private(set) var history: [RouteState] = []
    @Published private(set) var current: RouteState = RouteState(path: .list, params: RouteParams())
    
    func navigate(to route: RouteState) {
        history.append(current)
        current = route
    }
    
    func navigateBack() {
        if let previousRoute = history.popLast() {
            current = previousRoute
        }
    }
    
    func navigateToDetail(taskId: Int64) {
        navigate(to: RouteState(
            path: .detail,
            params: RouteParams(taskId: taskId)
        ))
    }
}

// Add these view components before BannerView
private struct ResizeHandle: View {
    @Binding var bannerWidth: CGFloat
    @Binding var isResizing: Bool
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isResizing = true
                        let delta = value.translation.width
                        bannerWidth = max(300, min(800, bannerWidth + delta))
                    }
                    .onEnded { _ in
                        isResizing = false
                        // Save the banner width to UserDefaults when resizing ends
                        UserDefaults.standard.set(bannerWidth, forKey: BANNER_WIDTH_KEY)
                    }
            )
    }
}

private struct BannerContentView: View {
    @EnvironmentObject var routeManager: RouteManager
    let task: TaskItem?
    @Binding var editingTaskId: Int64?
    @Binding var editingText: String
    @FocusState.Binding var isEditing: Bool
    let filteredTasks: [TaskItem]
    
    var body: some View {
        if let taskId = routeManager.current.params.taskId {
            if let task = task {
                TaskDetailView(task: task)
                    .environmentObject(routeManager)
                    .transition(.move(edge: .trailing))
            } else {
                Text("Task not found")
                    .foregroundColor(.secondary)
            }
        } else {
            Text("Invalid task ID")
                .foregroundColor(.secondary)
        }
    }
}

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @StateObject private var routeManager = RouteManager()
    @State private var isDragging: Bool = false
    @State private var editingTaskId: Int64? = nil
    @State private var editingText: String = ""
    
    // TaskViewMode enum for view filtering
    enum TaskViewMode {
        case unfinished  // Show only unfinished tasks (default)
        case all         // Show all active tasks
        case archived    // Show only archived tasks
    }
    
    @State private var viewMode: TaskViewMode = .unfinished
    @State private var recentlyFinishedTasks: Set<Int64> = []
    @State private var mode: TaskMode = .work
    @State private var isCollapsed: Bool = false
    @State private var bannerWidth: CGFloat = UserDefaults.standard.double(forKey: BANNER_WIDTH_KEY) > 0 ? UserDefaults.standard.double(forKey: BANNER_WIDTH_KEY) : 300
    @State private var isResizing: Bool = false
    @FocusState private var isEditing: Bool
    
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
    
    // Computed property for backward compatibility
    var showOnlyUnfinished: Bool {
        viewMode == .unfinished
    }
    
    var body: some View {
        VStack(spacing: 0) {
            BannerTopBar(
                isCollapsed: $isCollapsed,
                viewMode: $viewMode,
                mode: $mode
            )
            .environmentObject(routeManager)
            
            if !isCollapsed {
                Group {
                    if routeManager.current.path == .detail {
                        BannerContentView(
                            task: findTask(id: routeManager.current.params.taskId ?? 0),
                            editingTaskId: $editingTaskId,
                            editingText: $editingText,
                            isEditing: $isEditing,
                            filteredTasks: filteredTasks
                        )
                        .environmentObject(routeManager)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 0) {
                                ForEach(filteredTasks) { task in
                                    TaskItemWithSubtasks(
                                        task: task,
                                        editingTaskId: $editingTaskId,
                                        editingText: $editingText,
                                        isEditing: $isEditing,
                                        selectedTaskId: .constant(nil),
                                        onTaskSelect: { taskId in
                                            withAnimation {
                                                routeManager.navigateToDetail(taskId: taskId)
                                            }
                                        }
                                    )
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
        .environment(\.taskViewMode, viewMode)
        .frame(width: bannerWidth)
        .frame(minHeight: isCollapsed ? 1 : 300)
        .frame(maxHeight: isCollapsed ? 50 : 600)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .overlay(alignment: .trailing) {
            ResizeHandle(bannerWidth: $bannerWidth, isResizing: $isResizing)
        }
        .padding(.horizontal)
        .opacity(isDragging ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    if !isResizing {
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .animation(.easeInOut(duration: 0.2), value: routeManager.current.path)
        .onAppear {
            print("BannerView appeared with route: \(routeManager.current.path), params: \(routeManager.current.params)")
        }
        .onChange(of: routeManager.current) { newRoute in
            print("Route changed to: \(newRoute.path), params: \(newRoute.params), history: \(routeManager.history.count) items")
        }
    }
    
    private func findTask(id: Int64) -> TaskItem? {
        func search(in tasks: [TaskItem]) -> TaskItem? {
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
    private func filterUnfinishedTasks(_ task: TaskItem) -> Bool {
        if task.status == .archived {
            return false
        }
        if task.status == .created || recentlyFinishedTasks.contains(task.id) {
            return true
        }
        return task.subTasks.contains { filterUnfinishedTasks($0) }
    }
}

// Move ModeSwitcher to BannerTopBar.swift

private struct TaskItemWithSubtasks: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: TaskItem
    @Binding var editingTaskId: Int64?
    @Binding var editingText: String
    @FocusState.Binding var isEditing: Bool
    @Environment(\.showOnlyUnfinished) private var showOnlyUnfinished
    let indentLevel: Int
    @State private var recentlyFinishedTasks: Set<Int64> = []
    @Binding var selectedTaskId: Int64?
    let onTaskSelect: (Int64) -> Void
    
    init(task: TaskItem, editingTaskId: Binding<Int64?>, editingText: Binding<String>, isEditing: FocusState<Bool>.Binding, indentLevel: Int = 0, selectedTaskId: Binding<Int64?>, onTaskSelect: @escaping (Int64) -> Void) {
        self.task = task
        self._editingTaskId = editingTaskId
        self._editingText = editingText
        self._isEditing = isEditing
        self.indentLevel = indentLevel
        self._selectedTaskId = selectedTaskId
        self.onTaskSelect = onTaskSelect
    }
    
    var filteredSubTasks: [TaskItem] {
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
    private func filterUnfinishedTasks(_ task: TaskItem) -> Bool {
        if task.status == .archived {
            return false
        }
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

// Create an environment key for the task view mode
private struct TaskViewModeKey: EnvironmentKey {
    static let defaultValue: BannerView.TaskViewMode = .unfinished
}

extension EnvironmentValues {
    var showOnlyUnfinished: Bool {
        get { self[ShowOnlyUnfinishedKey.self] }
        set { self[ShowOnlyUnfinishedKey.self] = newValue }
    }
    
    var taskViewMode: BannerView.TaskViewMode {
        get { self[TaskViewModeKey.self] }
        set { self[TaskViewModeKey.self] = newValue }
    }
}

extension View {
    func delayedDisappearance(taskId: Int64, isFinished: Bool, delay: Double = 5.0, onFinished: @escaping (Int64) -> Void) -> some View {
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