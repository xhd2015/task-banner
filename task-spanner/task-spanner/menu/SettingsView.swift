import SwiftUI

struct StorageOptionButton: View {
    let type: StorageType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                Text(type.displayName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage Type")
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach([StorageType.userDefaults, .file, .remote], id: \.self) { type in
                            StorageOptionButton(
                                type: type,
                                isSelected: selectedStorageType == type
                            ) {
                                selectedStorageType = type
                                StorageType.current = type
                                Task {
                                    await taskManager.loadTasksFromStorage()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Text("Choose where to store your tasks. UserDefaults is suitable for small data, while File storage is better for larger datasets. Remote storage enables syncing across devices.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } header: {
                Text("Task Storage Location")
            }
        }
        .padding()
    }
}

private extension StorageType {
    var displayName: String {
        switch self {
        case .userDefaults:
            return "UserDefaults"
        case .file:
            return "File"
        case .remote:
            return "Remote(http://localhost:7021)"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TaskManager.shared)
} 
