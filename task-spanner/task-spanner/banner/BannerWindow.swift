import SwiftUI
import AppKit

// this is merely a placeholder, not a real window
class BannerWindow: NSWindow {
    init() {
        let screenSize = NSScreen.main?.visibleFrame ?? .zero
        let windowWidth: CGFloat = 300
        let windowHeight: CGFloat = 32
        
        let windowRect = NSRect(
            x: (screenSize.width - windowWidth) / 2,
            y: screenSize.height - windowHeight - 10,
            width: windowWidth,
            height: windowHeight
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .titled],
            backing: .buffered,
            defer: false
        )
        
        // Configure window properties
        self.level = .mainMenu + 1
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .transient]
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        
        // Make window key and accept keyboard input
        self.acceptsMouseMovedEvents = true
        self.isMovable = true
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}