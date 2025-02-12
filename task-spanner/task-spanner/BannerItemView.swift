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
                Button(action: commitEdit) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                .disabled(editingText.isEmpty)
                
                Button(action: cancelEdit) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
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
                
                Image(systemName: "clock")
                    .foregroundColor(.primary)
            }
            
            Text(task.title)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: startEditing) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: { isAddingSubTask = true }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            Text(task.startTime.formatted(date: .omitted, time: .shortened))
                .foregroundColor(.secondary)
                .font(.caption)
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
} 