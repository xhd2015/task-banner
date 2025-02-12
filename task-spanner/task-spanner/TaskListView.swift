import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var newTaskTitle: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            // Add new task section
            HStack {
                TextField("New task", text: $newTaskTitle, onCommit: addTask)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Add") {
                    addTask()
                }
                .disabled(newTaskTitle.isEmpty)
            }
            .padding(.horizontal)
            
            // Task list
            List {
                ForEach(taskManager.tasks) { task in
                    TaskRowView(task: task)
                }
                .onDelete { indices in
                    indices.forEach { index in
                        taskManager.removeTask(taskManager.tasks[index])
                    }
                }
            }
        }
        .frame(width: 300, height: 400)
    }
    
    private func addTask() {
        if !newTaskTitle.isEmpty {
            taskManager.addTask(ActiveTask(title: newTaskTitle, startTime: Date()))
            newTaskTitle = ""
        }
    }
}

struct TaskRowView: View {
    let task: ActiveTask
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(task.title)
                .font(.headline)
            
            Text("Started: \(task.startTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
} 