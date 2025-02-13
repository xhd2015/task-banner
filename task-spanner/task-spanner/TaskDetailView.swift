import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
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
                            HStack {
                                Image(systemName: subtask.status == .done ? "checkmark.square.fill" : "square")
                                    .foregroundColor(subtask.status == .done ? .green : .primary)
                                Text(subtask.title)
                                    .strikethrough(subtask.status == .done)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
    }
} 