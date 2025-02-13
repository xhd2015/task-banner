import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    @State private var newNote: String = ""
    @State private var editingNoteIndex: Int? = nil
    @State private var editingNoteText: String = ""
    @FocusState private var isEditingNote: Bool
    
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
                
                // Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.headline)
                    
                    HStack {
                        TextField("Add a note...", text: $newNote)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: addNote) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newNote.isEmpty)
                    }
                    
                    if !task.notes.isEmpty {
                        ForEach(task.notes.indices, id: \.self) { index in
                            if editingNoteIndex == index {
                                HStack(alignment: .top) {
                                    TextField("Edit note", text: $editingNoteText)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .focused($isEditingNote)
                                        .onSubmit(commitEdit)
                                    
                                    Button(action: commitEdit) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                    
                                    Button(action: cancelEdit) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            } else {
                                HStack(alignment: .top) {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(task.notes[index])
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Button(action: { startEditing(index) }) {
                                        Image(systemName: "pencil.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.vertical, 4)
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
            .padding()
        }
    }
    
    private func addNote() {
        guard !newNote.isEmpty else { return }
        taskManager.addNote(to: task, note: newNote)
        newNote = ""
    }
    
    private func startEditing(_ index: Int) {
        editingNoteIndex = index
        editingNoteText = task.notes[index]
        isEditingNote = true
    }
    
    private func commitEdit() {
        guard let index = editingNoteIndex,
              !editingNoteText.isEmpty else { return }
        taskManager.editNote(in: task, at: index, newText: editingNoteText)
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingNoteIndex = nil
        editingNoteText = ""
        isEditingNote = false
    }
} 