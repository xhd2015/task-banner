import SwiftUI

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isDragging: Bool = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingText: String = ""
    @State private var showOnlyUnfinished: Bool = true
    @FocusState private var isEditing: Bool
    
    var filteredTasks: [ActiveTask] {
        showOnlyUnfinished ? 
            taskManager.rootTasks.filter { filterUnfinishedTasks($0) } :
            taskManager.rootTasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Add toggle button at the top
            HStack {
                Button(action: { showOnlyUnfinished.toggle() }) {
                    Image(systemName: showOnlyUnfinished ? "checklist.unchecked" : "checklist")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                .padding(.vertical, 8)

                Spacer()
            }
            
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
        if task.status == .created {
            return true
        }
        // If task is done, check if any subtasks are unfinished
        return task.subTasks.contains { filterUnfinishedTasks($0) }
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
    
    init(task: ActiveTask, editingTaskId: Binding<UUID?>, editingText: Binding<String>, isEditing: FocusState<Bool>.Binding, indentLevel: Int = 0) {
        self.task = task
        self._editingTaskId = editingTaskId
        self._editingText = editingText
        self._isEditing = isEditing
        self.indentLevel = indentLevel
    }
    
    var filteredSubTasks: [ActiveTask] {
        showOnlyUnfinished ? 
            task.subTasks.filter { filterUnfinishedTasks($0) } :
            task.subTasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            BannerItemView(task: task, editingTaskId: $editingTaskId, editingText: $editingText, isEditing: $isEditing, indentLevel: indentLevel)
            
            ForEach(filteredSubTasks) { subTask in
                TaskItemWithSubtasks(task: subTask, editingTaskId: $editingTaskId, editingText: $editingText, isEditing: $isEditing, indentLevel: indentLevel + 1)
            }
        }
    }
    
    // Recursively filter tasks and their subtasks
    private func filterUnfinishedTasks(_ task: ActiveTask) -> Bool {
        if task.status == .created {
            return true
        }
        // If task is done, check if any subtasks are unfinished
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
