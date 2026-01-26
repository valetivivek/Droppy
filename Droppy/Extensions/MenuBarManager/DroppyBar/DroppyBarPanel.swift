//
//  DroppyBarPanel.swift
//  Droppy
//
//  Simplified Droppy Bar that shows user-selected app icons.
//  Click to activate the app.
//

import Cocoa
import SwiftUI

/// A floating panel that displays user-selected status menu icons.
@MainActor
final class DroppyBarPanel: NSPanel {
    
    /// Shared image cache
    let imageCache = MenuBarItemImageCache()
    
    /// The current screen
    private(set) var currentScreen: NSScreen?
    
    // MARK: - Initialization
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
    }
    
    private func setupPanel() {
        // Panel appearance - match Ice styling
        title = "Droppy Bar"
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        allowsToolTipsWhenApplicationIsInactive = true
        backgroundColor = .clear
        hasShadow = false  // Shadow handled by SwiftUI
        
        // Floating behavior
        level = .mainMenu + 1
        isFloatingPanel = true
        hidesOnDeactivate = false
        animationBehavior = .none
        
        // Collection behavior
        collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle, .moveToActiveSpace]
        
        // Accept first mouse
        acceptsMouseMovedEvents = true
    }
    
    // MARK: - Show/Hide
    
    /// Show the panel on the specified screen
    func show(on screen: NSScreen? = nil) async {
        // Find the screen with the mouse cursor if not specified
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = screen ?? NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        
        guard let targetScreen = targetScreen else { return }
        
        currentScreen = targetScreen
        
        // Update image cache before showing
        await imageCache.updateCache()
        
        // Create content view
        let hostingView = DroppyBarHostingView(
            rootView: DroppyBarContentView(imageCache: imageCache, closePanel: { [weak self] in
                self?.close()
            })
        )
        contentView = hostingView
        
        // Position and show
        updateOrigin(for: targetScreen)
        orderFrontRegardless()
        
        print("[DroppyBar] Shown on screen: \(targetScreen.localizedName)")
    }
    
    /// Update the panel position for the given screen
    private func updateOrigin(for screen: NSScreen) {
        let menuBarHeight: CGFloat = 24
        
        // Calculate origin Y: just below menu bar
        let originY = (screen.frame.maxY - 1) - menuBarHeight - frame.height
        
        // Calculate origin X: right side of screen, with padding
        let originX = screen.frame.maxX - frame.width - 8
        
        setFrameOrigin(CGPoint(x: originX, y: originY))
    }
    
    override func close() {
        super.close()
        contentView = nil
        currentScreen = nil
    }
}

// MARK: - DroppyBarHostingView

/// Custom hosting view that accepts first mouse
private final class DroppyBarHostingView: NSHostingView<DroppyBarContentView> {
    override var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - DroppyBarContentView

/// SwiftUI content view - Ice-style capsule bar with icons
struct DroppyBarContentView: View {
    @ObservedObject var imageCache: MenuBarItemImageCache
    let closePanel: () -> Void
    
    @State private var items: [MenuBarItem] = []
    
    private var contentHeight: CGFloat {
        imageCache.menuBarHeight ?? 24
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if items.isEmpty {
                if !CGPreflightScreenCaptureAccess() {
                    permissionNeededView
                } else {
                    emptyStateView
                }
            } else {
                ForEach(items) { item in
                    DroppyBarItemView(
                        item: item,
                        imageCache: imageCache,
                        closePanel: closePanel
                    )
                }
            }
        }
        .frame(height: contentHeight)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        // Ice-style capsule background
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.33), radius: 2.5)
        .padding(5)
        .fixedSize()
        .onAppear {
            loadItems()
        }
    }
    
    private var permissionNeededView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Screen recording required")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
    }
    
    private var emptyStateView: some View {
        Text("No menu bar items found")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
    }
    
    private func loadItems() {
        // Get menu bar items - filter out system items
        items = MenuBarItem.getMenuBarItems(onScreenOnly: false, activeSpaceOnly: true)
            .filter { item in
                // Skip system/utility items
                item.ownerName != "Control Center" &&
                item.ownerName != "Spotlight" &&
                item.ownerName != "Dock" &&
                item.ownerName != "SystemUIServer"
            }
        print("[DroppyBar] Loaded \(items.count) items")
    }
}

// MARK: - DroppyBarItemView

/// A single menu bar item in the Droppy Bar
struct DroppyBarItemView: View {
    let item: MenuBarItem
    @ObservedObject var imageCache: MenuBarItemImageCache
    let closePanel: () -> Void
    
    @State private var isHovering = false
    
    private var image: NSImage? {
        imageCache.getImage(for: item)
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback: show app icon
                if let app = item.owningApplication,
                   let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 4)
                }
            }
        }
        .background(isHovering ? Color.white.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            handleClick(rightClick: false)
        }
        .contextMenu {
            Button("Open \(item.displayName)") {
                handleClick(rightClick: false)
            }
        }
        .help(item.displayName)
    }
    
    private func handleClick(rightClick: Bool) {
        closePanel()
        
        // Simple approach: activate the owning app
        if let app = item.owningApplication {
            app.activate()
        }
        
        // Also try to click the actual menu bar item
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            MenuBarItemClicker.shared.clickItem(item, mouseButton: rightClick ? .right : .left)
        }
    }
}
