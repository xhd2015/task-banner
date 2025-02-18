import SwiftUI

struct IconButton: View {
    let systemName: String
    let action: () -> Void
    var color: Color = .secondary
    var font: Font? = nil
    var addTrailingPadding: Bool = true
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(color)
                .font(font)
        }
        .buttonStyle(.plain)
        .padding(.trailing, addTrailingPadding ? 8 : 0)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
} 