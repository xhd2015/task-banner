import SwiftUI

struct BannerView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var isDragging: Bool = false
    @State private var editingTaskId: UUID? = nil
    @State private var editingText: String = ""
    @FocusState private var isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(taskManager.tasks) { task in
                BannerItemView(
                    task: task,
                    editingTaskId: $editingTaskId,
                    editingText: $editingText,
                    isEditing: $isEditing
                )
                
                if task.id != taskManager.tasks.last?.id {
                    Divider()
                        .padding(.horizontal, 8)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 400, maxHeight: 300, alignment: .top)
        .padding(.vertical, 8)
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
