import SwiftUI

struct BannerTopBar: View {
    @Binding var isCollapsed: Bool
    @Binding var viewMode: BannerView.TaskViewMode
    @Binding var mode: TaskMode
    @EnvironmentObject var routeManager: RouteManager
    
    var body: some View {
        HStack {
            if routeManager.current.path == .detail {
                IconButton(
                    systemName: "chevron.left",
                    action: { 
                        withAnimation {
                            routeManager.navigateBack()
                        }
                    }
                )
            } else {
                IconButton(
                    systemName: {
                        switch viewMode {
                        case .unfinished: return "checklist.unchecked"
                        case .all: return "checklist"
                        case .archived: return "archivebox"
                        }
                    }(),
                    action: {
                        withAnimation {
                            switch viewMode {
                            case .unfinished: viewMode = .all
                            case .all: viewMode = .archived
                            case .archived: viewMode = .unfinished
                            }
                        }
                    }
                )
            }
            
            if routeManager.current.path == .list {
                ModeSwitcher(mode: $mode)
            } else {
                Text("Task Details")
                    .foregroundColor(.primary)
                    .font(.subheadline)
            }
            
            Spacer()
            
            IconButton(
                systemName: isCollapsed ? "chevron.down" : "chevron.up",
                action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                    }
                },
                font: .caption
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct ModeSwitcher: View {
    @Binding var mode: TaskMode
    @EnvironmentObject var taskManager: TaskManager
    
    private var displayModeText: String {
        mode.rawValue.uppercased()
    }
    
    var body: some View {
        Menu {
            ForEach([TaskMode.work,TaskMode.life]) { mode in
                Button(action: {
                    self.mode = mode
                    taskManager.switchMode(mode)
                }) {
                    HStack {
                        Text(mode.rawValue.uppercased())
                        if self.mode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(displayModeText)
                    .foregroundColor(.primary)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption2)
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }
} 
