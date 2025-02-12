import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var appState: AppState
    @State private var newTaskTitle: String = ""
    @State private var showFileExporter = false
    @State private var exportData: Data?
    
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
            
            Divider()
            
            HStack {
                Button(action: {
                    Task {
                        do {
                            exportData = try await taskManager.exportTasksToJSON()
                            showFileExporter = true
                        } catch {
                            print("Failed to export tasks: \(error)")
                        }
                    }
                }) {
                    Label("Export Tasks", systemImage: "square.and.arrow.up")
                }
                .fileExporter(
                    isPresented: $showFileExporter,
                    document: JSONDocument(data: exportData ?? Data()),
                    contentType: .json,
                    defaultFilename: "tasks.json"
                ) { result in
                    if case .failure(let error) = result {
                        print("Failed to save file: \(error)")
                    }
                }
                
                Spacer()
                
                Button {
                    print("Import button clicked")
                    appState.showFileImporter = true
                    print("showFileImporter set to true")
                } label: {
                    Label("Import Tasks", systemImage: "square.and.arrow.down")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
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

// Helper struct for file export
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
} 