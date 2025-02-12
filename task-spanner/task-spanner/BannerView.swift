import SwiftUI

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isDragging: Bool = false
    @State private var hoveredTaskId: UUID? = nil
    @State private var editingTaskId: UUID? = nil
    @State private var editingText: String = ""
    @FocusState private var isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(taskManager.tasks) { task in
                if editingTaskId == task.id {
                    // Edit mode
                    HStack {
                        TextField("Task", text: $editingText, onCommit: {
                            if !editingText.isEmpty {
                                taskManager.updateTask(task, newTitle: editingText)
                                editingTaskId = nil
                                isEditing = false
                            }
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isEditing)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isEditing = true
                                editingText = task.title
                            }
                        }
                        
                        Button("Save") {
                            if !editingText.isEmpty {
                                taskManager.updateTask(task, newTitle: editingText)
                                editingTaskId = nil
                                isEditing = false
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(editingText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Display mode
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.primary)
                        
                        Text(task.title)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Show edit button on hover
                        if hoveredTaskId == task.id {
                            Button(action: {
                                editingTaskId = task.id
                                editingText = task.title
                            }) {
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
                        hoveredTaskId = isHovered ? task.id : nil
                    }
                }
                
                if task.id != taskManager.tasks.last?.id {
                    Divider()
                        .padding(.horizontal, 8)
                }
            }
            
            Spacer(minLength: 0)  // Push content to top
        }
        .frame(maxWidth: 400, maxHeight: 300, alignment: .top)  // Added alignment: .top
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        }
        .padding(.horizontal)
        .opacity(isDragging ? 0.7 : 1.0)  // Visual feedback during drag
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
