import SwiftUI

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isDragging: Bool = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingText: String = ""
    @FocusState private var isEditing: Bool
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                ForEach(taskManager.rootTasks) { task in
                    TaskItemWithSubtasks(task: task, editingTaskId: $editingTaskId, editingText: $editingText, isEditing: $isEditing)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 400, minHeight: 300, maxHeight: 600)  // Added minHeight
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
}

private struct TaskItemWithSubtasks: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    @Binding var editingTaskId: UUID?
    @Binding var editingText: String
    @FocusState.Binding var isEditing: Bool
    let indentLevel: Int
    
    init(task: ActiveTask, editingTaskId: Binding<UUID?>, editingText: Binding<String>, isEditing: FocusState<Bool>.Binding, indentLevel: Int = 0) {
        self.task = task
        self._editingTaskId = editingTaskId
        self._editingText = editingText
        self._isEditing = isEditing
        self.indentLevel = indentLevel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            BannerItemView(task: task, editingTaskId: $editingTaskId, editingText: $editingText, isEditing: $isEditing, indentLevel: indentLevel)
            
            ForEach(task.subTasks) { subTask in
                TaskItemWithSubtasks(task: subTask, editingTaskId: $editingTaskId, editingText: $editingText, isEditing: $isEditing, indentLevel: indentLevel + 1)
            }
        }
    }
} 
