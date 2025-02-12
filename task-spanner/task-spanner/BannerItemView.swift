import SwiftUI

struct BannerItemView: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    
    @Binding var editingTaskId: UUID?
    @Binding var editingText: String
    @FocusState.Binding var isEditing: Bool
    @State private var isHovered: Bool = false
    
    var body: some View {
        Group {
            if editingTaskId == task.id {
                editingView
            } else {
                displayView
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
            
            Button("Save", action: commitEdit)
                .buttonStyle(.borderless)
                .disabled(editingText.isEmpty)
        }
        .padding(.horizontal, 16)
    }
    
    private var displayView: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.primary)
            
            Text(task.title)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered {
                Button(action: startEditing) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.borderless)
            }
            
            Text(task.startTime.formatted(date: .omitted, time: .shortened))
                .foregroundColor(.secondary)
                .font(.caption)
        }
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
} 