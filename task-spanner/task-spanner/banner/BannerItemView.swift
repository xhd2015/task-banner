import SwiftUI

struct BannerItemView: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    
    @Binding var editingTaskId: UUID?
    @Binding var editingText: String
    @FocusState.Binding var isEditing: Bool
    @State private var isHovered: Bool = false
    @State private var isAddingSubTask: Bool = false
    @State private var newSubTaskText: String = ""
    @FocusState private var isSubTaskEditing: Bool
    let indentLevel: Int
    let onTaskSelect: (UUID) -> Void
    @Binding var recentlyFinishedTasks: Set<UUID>
    
    @Environment(\.showOnlyUnfinished) private var showOnlyUnfinished
    
    init(task: ActiveTask, 
         editingTaskId: Binding<UUID?>, 
         editingText: Binding<String>, 
         isEditing: FocusState<Bool>.Binding, 
         indentLevel: Int = 0,
         onTaskSelect: @escaping (UUID) -> Void,
         recentlyFinishedTasks: Binding<Set<UUID>> = .constant([])) {
        self.task = task
        self._editingTaskId = editingTaskId
        self._editingText = editingText
        self._isEditing = isEditing
        self.indentLevel = indentLevel
        self.onTaskSelect = onTaskSelect
        self._recentlyFinishedTasks = recentlyFinishedTasks
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if editingTaskId == task.id {
                    editingView
                } else {
                    displayView
                }
            }
            
            if isAddingSubTask {
                HStack {
                    Text("↳")
                        .foregroundColor(.secondary)
                    
                    TextField("New sub-task", text: $newSubTaskText, onCommit: commitAddSubTask)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isSubTaskEditing)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSubTaskEditing = true
                            }
                        }
                    
                    HStack(spacing: 8) {
                        Button(action: commitAddSubTask) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.borderless)
                        .disabled(newSubTaskText.isEmpty)
                        
                        Button(action: cancelAddSubTask) {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.leading, CGFloat(indentLevel + 1) * 16 + 16)
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var editingView: some View {
        HStack {
            TextField("Task", text: $editingText, onCommit: commitEdit)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isEditing)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isEditing = true
                        editingText = task.title
                    }
                }
            
            HStack(spacing: 8) {
                IconButton(systemName: "checkmark.circle", action: commitEdit, color: .green)
                    .disabled(editingText.isEmpty)
                
                IconButton(systemName: "xmark.circle", action: cancelEdit, color: .red)
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var displayView: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<indentLevel, id: \.self) { _ in
                    Text("│")
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                if indentLevel > 0 {
                    Text("├")
                        .foregroundColor(.secondary.opacity(0.5))
                }
                
                IconButton(
                    systemName: task.status == .done || recentlyFinishedTasks.contains(task.id) ? "checkmark.square.fill" : "square",
                    action: toggleStatus,
                    color: task.status == .done || recentlyFinishedTasks.contains(task.id) ? .green : .primary,
                    addTrailingPadding: false
                )
            }
            
            Text(task.title)
                .foregroundColor(task.status == .done || recentlyFinishedTasks.contains(task.id) ? .secondary : .primary)
                .lineLimit(1)
                .strikethrough(task.status == .done || recentlyFinishedTasks.contains(task.id))
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 2) {
                    Group {
                        let isFirst = task.parentId == nil ? 
                            taskManager.tasks.first?.id == task.id :
                            taskManager.tasks.first(where: { $0.id == task.parentId })?.subTasks.first?.id == task.id
                            
                        let isLast = task.parentId == nil ?
                            taskManager.tasks.last?.id == task.id :
                            taskManager.tasks.first(where: { $0.id == task.parentId })?.subTasks.last?.id == task.id
                        
                        IconButton(
                            systemName: "arrow.up",
                            action: { taskManager.moveTask(task, direction: .up) },
                            color: isFirst ? .secondary : .primary,
                            addTrailingPadding: false
                        )
                        .disabled(isFirst)
                        
                        IconButton(
                            systemName: "arrow.down",
                            action: { taskManager.moveTask(task, direction: .down) },
                            color: isLast ? .secondary : .primary,
                            addTrailingPadding: false
                        )
                        .disabled(isLast)
                    }
                    
                    IconButton(
                        systemName: "square.and.pencil",
                        action: startEditing,
                        addTrailingPadding: false
                    )
                    
                    IconButton(
                        systemName: "plus.circle",
                        action: { isAddingSubTask = true },
                        addTrailingPadding: false
                    )
                }
            }
            
            Text(task.startTime.formatted(date: .omitted, time: .shortened))
                .foregroundColor(.secondary)
                .font(.caption)
            
            IconButton(
                systemName: "chevron.right",
                action: { onTaskSelect(task.id) },
                color: .secondary,
                font: .caption,
                addTrailingPadding: false
            )
        }
        .padding(.leading, CGFloat(indentLevel) * 16)
        .padding(.horizontal, 16)
        .onHover { isHovered in
            self.isHovered = isHovered
        }
    }
    
    private func startEditing() {
        editingTaskId = task.id
        editingText = task.title
    }
    
    private func commitEdit() {
        if !editingText.isEmpty {
            taskManager.updateTask(task, newTitle: editingText)
            editingTaskId = nil
            isEditing = false
        }
    }
    
    private func cancelEdit() {
        editingTaskId = nil
        isEditing = false
        editingText = task.title
    }
    
    private func commitAddSubTask() {
        if !newSubTaskText.isEmpty {
            Task {
                do {
                    try await taskManager.addSubTask(to: task, title: newSubTaskText)
                    cancelAddSubTask()
                } catch {
                    print("Failed to add sub-task: \(error)")
                }
            }
        }
    }
    
    private func cancelAddSubTask() {
        isAddingSubTask = false
        isSubTaskEditing = false
        newSubTaskText = ""
    }
    
    private func toggleStatus() {
        let newStatus: TaskStatus = task.status == .done ? .created : .done
        if newStatus == .done && showOnlyUnfinished {
            recentlyFinishedTasks.insert(task.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                recentlyFinishedTasks.remove(task.id)
                taskManager.updateTaskStatus(task, newStatus: newStatus)
            }
        }else {
            // directly update status
            taskManager.updateTaskStatus(task, newStatus: newStatus)
        }
    }
} 