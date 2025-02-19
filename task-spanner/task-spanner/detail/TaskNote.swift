import SwiftUI

struct TaskNote: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: TaskItem
    @State private var newNote: String = ""
    @State private var editingNoteIndex: Int? = nil
    @State private var editingNoteText: String = ""
    @FocusState private var isEditingNote: Bool
    
    // Combine notes from task and subtasks
    private struct NoteWithSource {
        let text: String
        let source: String
        let taskRef: TaskItem
        let indexInSource: Int
    }
    
    private var allNotes: [NoteWithSource] {
        var notes: [NoteWithSource] = []
        
        // Add main task notes
        for (index, note) in task.notes.enumerated() {
            notes.append(NoteWithSource(
                text: note,
                source: "Main Task",
                taskRef: task,
                indexInSource: index
            ))
        }
        
        // Add subtask notes
        for subtask in task.subTasks {
            for (index, note) in subtask.notes.enumerated() {
                notes.append(NoteWithSource(
                    text: note,
                    source: "Subtask: \(subtask.title)",
                    taskRef: subtask,
                    indexInSource: index
                ))
            }
        }
        
        // Sort by most recent first (assuming notes are added in chronological order)
        return notes.reversed()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
            
            HStack {
                TextField("Add a note...", text: $newNote)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                IconButton(
                    systemName: "plus.circle.fill",
                    action: addNote,
                    color: .blue,
                    addTrailingPadding: false
                )
                .disabled(newNote.isEmpty)
            }
            
            if !allNotes.isEmpty {
                ForEach(allNotes.indices, id: \.self) { index in
                    let note = allNotes[index]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TaskNoteItem(
                            task: note.taskRef,
                            index: note.indexInSource,
                            text: note.text,
                            editingNoteIndex: $editingNoteIndex,
                            editingNoteText: $editingNoteText,
                            isEditingNote: $isEditingNote
                        )
                    }
                }
            } else {
                Text("No notes yet")
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func addNote() {
        guard !newNote.isEmpty else { return }
        taskManager.addNote(to: task, note: newNote)
        newNote = ""
    }
} 
