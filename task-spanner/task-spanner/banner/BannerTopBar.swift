import SwiftUI

struct BannerTopBar: View {
    @Binding var isCollapsed: Bool
    @Binding var showOnlyUnfinished: Bool
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
                    systemName: showOnlyUnfinished ? "checklist.unchecked" : "checklist",
                    action: { showOnlyUnfinished.toggle() }
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
    
    var body: some View {
        Menu {
            ForEach(TaskMode.allCases) { mode in
                Button(action: { self.mode = mode }) {
                    HStack {
                        Text(mode.rawValue)
                        if self.mode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(mode.rawValue)
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
