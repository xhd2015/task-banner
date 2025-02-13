import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var routeManager: RouteManager
    let task: ActiveTask
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Group {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Task Information")
                            .font(.headline)
                        
                        HStack {
                            Text("Title")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(task.title)
                        }
                        
                        HStack {
                            Text("Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(task.status.rawValue.capitalized)
                                .foregroundColor(task.status == .done ? .green : .blue)
                        }
                        
                        HStack {
                            Text("Start Time")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(task.startTime.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
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
                                Button(action: {
                                    taskManager.updateTaskStatus(subtask, newStatus: subtask.status == .done ? .created : .done)
                                }) {
                                    Image(systemName: subtask.status == .done ? "checkmark.square.fill" : "square")
                                        .foregroundColor(subtask.status == .done ? .green : .primary)
                                }
                                .buttonStyle(.plain)
                                
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
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
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