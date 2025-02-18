import SwiftUI

struct TaskNoteItem: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: ActiveTask
    let index: Int
    let text: String
    @Binding var editingNoteIndex: Int?
    @Binding var editingNoteText: String
    @FocusState.Binding var isEditingNote: Bool
    
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
    
    private func startEditing() {
        editingNoteIndex = index
        editingNoteText = text
        isEditingNote = true
    }
    
    private func commitEdit() {
        guard !editingNoteText.isEmpty else { return }
        taskManager.editNote(in: task, at: index, newText: editingNoteText)
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingNoteIndex = nil
        editingNoteText = ""
        isEditingNote = false
    }
    
    var body: some View {
        if editingNoteIndex == index {
            HStack(alignment: .top) {
                TextField("Edit note", text: $editingNoteText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isEditingNote)
                    .onSubmit(commitEdit)
                
                IconButton(
                    systemName: "checkmark.circle.fill",
                    action: commitEdit,
                    color: .green,
                    addTrailingPadding: false
                )
                
                IconButton(
                    systemName: "xmark.circle.fill",
                    action: cancelEdit,
                    color: .red,
                    addTrailingPadding: false
                )
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .top) {
                Text("•")
                    .foregroundColor(.secondary)
                renderNoteText(text)
                Spacer()
                IconButton(
                    systemName: "pencil.circle",
                    action: startEditing,
                    color: .blue,
                    addTrailingPadding: false
                )
            }
            .padding(.vertical, 4)
        }
    }
} 