import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var routeManager: RouteManager
    let task: TaskItem
    
    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day, .month, .year], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)y ago"
        } else if let month = components.month, month > 0 {
            return "\(month)mo ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "just now"
        }
    }
    
    private var taskHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.status == .archived ? "archivebox.fill" : 
                               (task.status == .done ? "checkmark.circle.fill" : "circle"))
                    .foregroundColor(task.status == .archived ? .gray :
                                    (task.status == .done ? .green : .blue))
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundColor(task.status == .archived ? .gray :
                                        (task.status == .done ? .secondary : .primary))
                        .italic(task.status == .archived)
                    
                    Text(relativeTimeString(from: task.startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Archive/Unarchive Button
                Button(action: toggleArchive) {
                    Label(
                        task.status == .archived ? "Unarchive" : "Archive",
                        systemImage: task.status == .archived ? "tray.and.arrow.up" : "archivebox"
                    )
                    .foregroundColor(task.status == .archived ? .blue : .gray)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    // Function to toggle archive status
    private func toggleArchive() {
        let newStatus: TaskStatus = task.status == .archived ? .created : .archived
        Task {
            try? await taskManager.updateTaskStatus(task, newStatus: newStatus)
        }
    }
    
    private var subtasksView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subtasks (\(task.subTasks.count))")
                .font(.headline)
            
            ForEach(task.subTasks) { subtask in
                SubtaskRow(subtask: subtask)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                taskHeaderView
                
                if !task.subTasks.isEmpty {
                    subtasksView
                }
                
                TaskNote(task: task)
            }
            .padding()
        }
    }
}

private struct SubtaskRow: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var routeManager: RouteManager
    let subtask: TaskItem
    
    var body: some View {
        HStack(spacing: 8) {
            IconButton(
                systemName: subtask.status == .done ? "checkmark.square.fill" : "square",
                action: {
                     Task {
                        try? await taskManager.updateTaskStatus(subtask, newStatus: subtask.status == .done ? .created : .done)
                    }
                },
                color: subtask.status == .done ? .green : .primary,
                addTrailingPadding: false
            )
            
            Button(action: {
                withAnimation {
                    routeManager.navigateToDetail(taskId: subtask.id)
                }
            }) {
                HStack {
                    Text(subtask.title)
                        .strikethrough(subtask.status == .done)
                        .foregroundColor(.primary)
                    Spacer()
                    IconButton(
                        systemName: "chevron.right",
                        action: {
                            withAnimation {
                                routeManager.navigateToDetail(taskId: subtask.id)
                            }
                        },
                        color: .secondary,
                        font: .caption,
                        addTrailingPadding: false
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }
} 
