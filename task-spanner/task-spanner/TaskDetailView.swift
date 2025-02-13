import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    @State private var newNote: String = ""
    @State private var editingNoteIndex: Int? = nil
    @State private var editingNoteText: String = ""
    @FocusState private var isEditingNote: Bool
    
    private func renderNoteText(_ text: String) -> some View {
        let components = extractLinksAndText(from: text)
        return HStack(alignment: .center, spacing: 4) {
            ForEach(components.indices, id: \.self) { index in
                let component = components[index]
                if let url = URL(string: component), component.lowercased().hasPrefix("http") {
                    Link(destination: url) {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    }
                } else {
                    Text(component)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private func extractLinksAndText(from text: String) -> [String] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        var components: [String] = []
        var currentIndex = text.startIndex
        
        detector?.enumerateMatches(in: text, range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            if let match = match, let range = Range(match.range, in: text) {
                // Add text before the link if any
                if currentIndex < range.lowerBound {
                    components.append(String(text[currentIndex..<range.lowerBound]))
                }
                // Add the link
                components.append(String(text[range]))
                currentIndex = range.upperBound
            }
        }
        
        // Add remaining text after the last link if any
        if currentIndex < text.endIndex {
            components.append(String(text[currentIndex...]))
        }
        
        return components.filter { !$0.isEmpty }
    }
    
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
                                    renderNoteText(task.notes[index])
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