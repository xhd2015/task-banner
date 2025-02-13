//
//  task_spannerApp.swift
//  task-spanner
//
//  Created by xhd2015 on 2/12/25.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var showFileImporter = false {
        didSet {
            print("AppState: showFileImporter changed from \(oldValue) to \(showFileImporter)")
        }
    }
    
    @Published var showFileExporter = false
    @Published var exportData: Data?
    
    func startExport(data: Data) {
        exportData = data
        showFileExporter = true
    }
}

@main
struct task_spannerApp: App {
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Settings {
            FileImporterView()
                .environmentObject(taskManager)
                .environmentObject(appState)
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
        
        MenuBarExtra("Task Spanner", systemImage: "list.clipboard") {
            TaskListView()
                .environmentObject(taskManager)
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

struct FileImporterView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        EmptyView()
            .fileImporter(
                isPresented: $appState.showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                print("fileImporter completion called")
                switch result {
                case .success(let files):
                    print("File import succeeded, files: \(files)")
                    guard let selectedFile = files.first else {
                        print("No file selected")
                        return
                    }
                    
                    do {
                        // Start accessing the security-scoped resource
                        guard selectedFile.startAccessingSecurityScopedResource() else {
                            print("Failed to access security scoped resource")
                            return
                        }
                        
                        defer {
                            // Make sure to release the security-scoped resource when done
                            selectedFile.stopAccessingSecurityScopedResource()
                        }
                        
                        let data = try Data(contentsOf: selectedFile)
                        print("Successfully read file data, size: \(data.count) bytes")
                        Task {
                            do {
                                try await taskManager.importTasksFromJSON(data)
                                print("Successfully imported tasks")
                            } catch {
                                print("Failed to import tasks: \(error)")
                            }
                        }
                    } catch {
                        print("Failed to read file: \(error)")
                    }
                    
                case .failure(let error):
                    print("Import error: \(error.localizedDescription)")
                }
            }
            .fileExporter(
                isPresented: $appState.showFileExporter,
                document: JSONDocument(data: appState.exportData ?? Data()),
                contentType: .json,
                defaultFilename: "tasks.json"
            ) { result in
                if case .failure(let error) = result {
                    print("Failed to export file: \(error)")
                } else {
                    print("Successfully exported tasks")
                }
            }
    }
}
