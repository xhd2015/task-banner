import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedStorageType: StorageType = StorageType.current
    
    var body: some View {
        TabView {
            storageSettingsView
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }
        }
        .frame(width: 450, height: 250)
    }
    
    private var storageSettingsView: some View {
        Form {
            Section {
                Picker("Storage Type", selection: $selectedStorageType) {
                    Text("UserDefaults").tag(StorageType.userDefaults)
                    Text("File").tag(StorageType.file)
                }
                .onChange(of: selectedStorageType) { newValue in
                    StorageType.current = newValue
                    Task {
                        await taskManager.loadTasksFromStorage()
                    }
                }
                
                Text("Choose where to store your tasks. UserDefaults is suitable for small data, while File storage is better for larger datasets.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } header: {
                Text("Task Storage Location")
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(TaskManager.shared)
} 