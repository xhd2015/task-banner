import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var routeManager: RouteManager
    let task: ActiveTask
    
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    VStack(alignment: .leading, spacing: 12) {
                        // Task content and status
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.status == .done ? .green : .blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.headline)
                                    .foregroundColor(task.status == .done ? .secondary : .primary)
                                
                                Text(relativeTimeString(from: task.startTime))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                if !task.subTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subtasks (\(task.subTasks.count))")
                            .font(.headline)
                        
                        ForEach(task.subTasks) { subtask in
                            HStack(spacing: 8) {
                                // Status toggle button
                                IconButton(
                                    systemName: subtask.status == .done ? "checkmark.square.fill" : "square",
                                    action: {
                                        taskManager.updateTaskStatus(subtask, newStatus: subtask.status == .done ? .created : .done)
                                    },
                                    color: subtask.status == .done ? .green : .primary,
                                    addTrailingPadding: false
                                )
                                
                                // Navigation button for the rest of the row
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
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Notes Section
                TaskNote(task: task)
            }
            .padding()
        }
    }
} 