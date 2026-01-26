//
//  MenuBarCoverPanel.swift
//  Droppy
//
//  Creates an overlay window that covers (hides) selected menu bar items
//  Uses a simple approach: draws a solid bar that extends from the left edge
//  to just before the Droppy divider position
//

import SwiftUI
import AppKit

/// A panel that overlays the menu bar to visually hide items to the left of the divider
@MainActor
class MenuBarCoverPanel: NSPanel {
    
    /// The width of the cover (how far from left edge to cover)
    private var coverWidth: CGFloat = 0
    
    /// Timer to update cover
    private var updateTimer: Timer?
    
    /// Reference to items being covered
    private var coveredOwnerNames: Set<String> = []
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Critical: Position ABOVE menu bar items (status window level + 2)
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 2)
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresHidden, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true // Let clicks pass through
        self.isReleasedWhenClosed = false
        
        print("[MenuBarCoverPanel] Initialized with level: \(self.level.rawValue)")
    }
    
    /// Update the cover to hide the specified items by owner name
    func updateCover(forOwnerNames ownerNames: Set<String>) {
        self.coveredOwnerNames = ownerNames
        
        guard !ownerNames.isEmpty else {
            orderOut(nil)
            return
        }
        
        // Get the menu bar screen
        guard let screen = NSScreen.main else { 
            print("[MenuBarCoverPanel] No main screen")
            return 
        }
        
        // Get all menu bar items and find the ones we need to cover
        let allItems = MenuBarItem.getMenuBarItems()
        let itemsToCover = allItems.filter { ownerNames.contains($0.ownerName) }
        
        guard !itemsToCover.isEmpty else {
            print("[MenuBarCoverPanel] No items found to cover")
            orderOut(nil)
            return
        }
        
        // Calculate cover regions for each item
        // CoreGraphics uses top-left origin, AppKit uses bottom-left
        var coverRects: [CGRect] = []
        
        for item in itemsToCover {
            // Convert CG frame to AppKit frame
            let cgFrame = item.frame
            // Y in CG: 0 = top of screen
            // Y in AppKit: 0 = bottom of screen
            let appKitY = screen.frame.height - cgFrame.maxY
            
            let rect = CGRect(
                x: cgFrame.origin.x,
                y: appKitY,
                width: cgFrame.width,
                height: cgFrame.height
            )
            coverRects.append(rect)
            print("[MenuBarCoverPanel] Item '\(item.ownerName)' frame CG: \(cgFrame) -> AppKit: \(rect)")
        }
        
        // Set panel frame to cover the entire menu bar
        let menuBarHeight: CGFloat = 37
        let panelFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - menuBarHeight,
            width: screen.frame.width,
            height: menuBarHeight
        )
        
        setFrame(panelFrame, display: false)
        
        // Create view with cover rectangles (convert to panel-local coordinates)
        let localRects = coverRects.map { rect -> CGRect in
            CGRect(
                x: rect.origin.x - panelFrame.origin.x,
                y: rect.origin.y - panelFrame.origin.y,
                width: rect.width,
                height: rect.height
            )
        }
        
        let coverView = SimpleMenuBarCoverView(rects: localRects)
        contentView = NSHostingView(rootView: coverView)
        
        orderFrontRegardless()
        
        print("[MenuBarCoverPanel] Covering \(itemsToCover.count) items, panel frame: \(panelFrame)")
    }
    
    /// Start auto-updating the cover positions
    func startAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.coveredOwnerNames.isEmpty else { return }
                self.updateCover(forOwnerNames: self.coveredOwnerNames)
            }
        }
        print("[MenuBarCoverPanel] Auto-update started")
    }
    
    /// Stop auto-updating
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Clear the cover (show all items)
    func clearCover() {
        coveredOwnerNames = []
        orderOut(nil)
        print("[MenuBarCoverPanel] Cover cleared")
    }
}

/// Simple SwiftUI view that draws solid rectangles to cover items
struct SimpleMenuBarCoverView: View {
    let rects: [CGRect]
    
    var body: some View {
        Canvas { context, size in
            // Get the menu bar background color based on appearance
            let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let coverColor = isDarkMode 
                ? Color(nsColor: NSColor(white: 0.15, alpha: 1.0))  // Dark mode menu bar
                : Color(nsColor: NSColor(white: 0.98, alpha: 1.0))  // Light mode menu bar
            
            for rect in rects {
                // Draw a solid rectangle with slight padding
                let paddedRect = CGRect(
                    x: rect.origin.x - 2,
                    y: size.height - rect.origin.y - rect.height - 2,
                    width: rect.width + 4,
                    height: rect.height + 4
                )
                
                context.fill(
                    Path(roundedRect: paddedRect, cornerRadius: 0),
                    with: .color(coverColor)
                )
            }
        }
        .ignoresSafeArea()
    }
}
