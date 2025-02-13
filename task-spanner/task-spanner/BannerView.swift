import SwiftUI

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isDragging: Bool = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingText: String = ""
    @State private var showOnlyUnfinished: Bool = true
    @State private var recentlyFinishedTasks: Set<UUID> = []
    @State private var mode: TaskMode = .work
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
            // Updated top bar with mode switch
            HStack {
                // Existing toggle button
                Button(action: { showOnlyUnfinished.toggle() }) {
                    Image(systemName: showOnlyUnfinished ? "checklist.unchecked" : "checklist")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                .padding(.vertical, 8)
                
                // Add mode switch
                ModeSwitcher(mode: $mode)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(filteredTasks) { task in
                        TaskItemWithSubtasks(task: task, 
                            editingTaskId: $editingTaskId, 
                            editingText: $editingText, 
                            isEditing: $isEditing)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .environment(\.showOnlyUnfinished, showOnlyUnfinished)
        .frame(maxWidth: 400, minHeight: 300, maxHeight: 600)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal)
        .opacity(isDragging ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
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
    
    init(task: ActiveTask, editingTaskId: Binding<UUID?>, editingText: Binding<String>, isEditing: FocusState<Bool>.Binding, indentLevel: Int = 0) {
        self.task = task
        self._editingTaskId = editingTaskId
        self._editingText = editingText
        self._isEditing = isEditing
        self.indentLevel = indentLevel
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
                recentlyFinishedTasks: $recentlyFinishedTasks)
            
            ForEach(filteredSubTasks) { subTask in
                TaskItemWithSubtasks(task: subTask, 
                    editingTaskId: $editingTaskId, 
                    editingText: $editingText, 
                    isEditing: $isEditing, 
                    indentLevel: indentLevel + 1)
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
}

// Add this enum at the bottom of the file
enum TaskMode: String, CaseIterable, Identifiable {
    case work = "WORK"
    case life = "LIFE"
    
    var id: Self { self }
} 
