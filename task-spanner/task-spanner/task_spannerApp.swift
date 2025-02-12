//
//  task_spannerApp.swift
//  task-spanner
//
//  Created by xhd2015 on 2/12/25.
//

import SwiftUI

@main
struct task_spannerApp: App {
    @StateObject private var taskManager = TaskManager.shared
    
    var body: some Scene {
        Settings {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
        
        MenuBarExtra("Task Spanner", systemImage: "list.clipboard") {
            TaskListView()
                .environmentObject(taskManager)
        }
        .menuBarExtraStyle(.window)
    }
}
