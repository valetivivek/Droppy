//
//  DragMonitor.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//
//  Uses NSPasteboard(name: .drag) polling to detect drag operations.
//  This approach works without Accessibility permissions, unlike NSEvent global monitors.
//

import AppKit
import Combine

/// Monitors system-wide drag events to detect when files/items are being dragged
final class DragMonitor: ObservableObject {
    /// Shared instance for app-wide access
    static let shared = DragMonitor()
    
    /// Whether a drag operation with droppable content is in progress
    @Published private(set) var isDragging = false
    
    /// The current mouse location during drag
    @Published private(set) var dragLocation: CGPoint = .zero
    
    /// Whether a jiggle gesture was detected during drag (triggers basket)
    @Published private(set) var didJiggle = false
    
    private var isMonitoring = false
    private var dragStartChangeCount: Int = 0
    private var dragActive = false
    
    // Jiggle detection state
    private var lastDragLocation: CGPoint = .zero
    private var lastDragDirection: CGPoint = .zero
    private var directionChanges: [Date] = []
    private let jiggleThreshold: Int = 3
    private let jiggleTimeWindow: TimeInterval = 0.5
    
    // Flags to prevent duplicate notifications
    private var jiggleNotified = false
    private var dragEndNotified = false
    
    private init() {}
    
    /// Starts monitoring for drag events
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorLoop()
    }
    
    /// Stops monitoring for drag events
    func stopMonitoring() {
        isMonitoring = false
    }
    
    private func monitorLoop() {
        guard isMonitoring else { return }
        
        // CRITICAL: Only access NSEvent class properties if we're truly on the main thread
        // and not during system event dispatch to avoid race conditions with HID event decoding
        if Thread.isMainThread {
            checkForActiveDrag()
        }
        
        // Increased interval from 50ms to 100ms to reduce collision chance with system event processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.monitorLoop()
        }
    }
    
    /// Resets jiggle state (called after basket is shown or drag ends)
    func resetJiggle() {
        didJiggle = false
        jiggleNotified = false
        directionChanges.removeAll()
        lastDragDirection = .zero
    }
    
    /// Manually set dragging state for system-initiated drags (e.g., Dock folder drags)
    /// NSPasteboard(name: .drag) polling doesn't work for Dock folder drags - the changeCount
    /// isn't updated until later in the drag. This allows NotchDragContainer.draggingEntered()
    /// to manually activate the drag state when it receives a drag via NSDraggingDestination.
    /// Fixes Issue #136: Dock folder drags not showing shelf action buttons.
    func forceSetDragging(_ isDragging: Bool, location: CGPoint? = nil) {
        guard self.isDragging != isDragging else { return }  // Avoid redundant changes
        
        print("🔧 DragMonitor.forceSetDragging(\(isDragging)) - Dock folder/system drag workaround")
        
        if isDragging {
            dragActive = true
            self.isDragging = true
            if let loc = location {
                dragLocation = loc
                lastDragLocation = loc
            }
            dragEndNotified = false
            resetJiggle()
        } else {
            dragActive = false
            self.isDragging = false
            dragEndNotified = true
            resetJiggle()
        }
    }
    
    /// Force reset ALL drag state (called after screen unlock when state may be corrupted)
    /// After SkyLight delegation, the drag polling state can get stuck, blocking hover detection
    func forceReset() {
        print("🧹 DragMonitor.forceReset() called - clearing stuck drag state")
        dragActive = false
        isDragging = false
        dragLocation = .zero
        dragStartChangeCount = 0
        dragEndNotified = true
        resetJiggle()
        
        // SKYLIGHT DEBUG: Enable verbose logging for a few seconds after unlock
        DragMonitor.unlockTime = Date()
    }
    
    /// Timestamp of last unlock - used to trigger verbose logging in NotchWindow.handleGlobalMouseEvent
    static var unlockTime: Date = .distantPast

    private func checkForActiveDrag() {
        autoreleasepool {
            // SAFETY: Cache NSEvent class properties immediately to minimize
            // repeated access during HID event system contention
            let mouseIsDown = NSEvent.pressedMouseButtons & 1 != 0
            let currentMouseLocation = NSEvent.mouseLocation
            
            // DEBUG: Log state periodically to trace stuck isDragging after SkyLight unlock
            struct DragDebugCounter { static var lastLog = Date.distantPast }
            if Date().timeIntervalSince(DragDebugCounter.lastLog) > 2.0 {
                print("🐉 DragMonitor.checkForActiveDrag: isDragging=\(isDragging), dragActive=\(dragActive), mouseIsDown=\(mouseIsDown)")
                DragDebugCounter.lastLog = Date()
            }
            
            // Optimization: If mouse is not down and we are not tracking a drag, 
            // return early to avoid unnecessary NSPasteboard allocation/release (which caused crashes)
            if !mouseIsDown && !dragActive {
                return
            }

            // Retrieve pasteboard handle locally to ensure validity
            let dragPasteboard = NSPasteboard(name: .drag)
            let currentChangeCount = dragPasteboard.changeCount
            
            // Detect drag START
            if currentChangeCount != dragStartChangeCount && mouseIsDown {
                let hasContent = (dragPasteboard.types?.count ?? 0) > 0
                if hasContent && !dragActive {
                    dragActive = true
                    dragStartChangeCount = currentChangeCount
                    resetJiggle()
                    dragEndNotified = false
                    lastDragLocation = currentMouseLocation
                    isDragging = true
                    dragLocation = currentMouseLocation
                    
                    // Check if instant basket mode is enabled
                    let instantMode = UserDefaults.standard.bool(forKey: "instantBasketOnDrag")
                    if instantMode {
                        // Get user-configured delay (minimum 0.15s to let drag "settle")
                        let configuredDelay = UserDefaults.standard.double(forKey: "instantBasketDelay")
                        let delay = max(0.15, configuredDelay > 0 ? configuredDelay : 0.15)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                            // Only show if drag is still active (user didn't release)
                            guard self?.dragActive == true else { return }
                            let enabled = UserDefaults.standard.bool(forKey: "enableFloatingBasket")
                            if enabled || UserDefaults.standard.object(forKey: "enableFloatingBasket") == nil {
                                FloatingBasketWindowController.shared.onJiggleDetected()
                            }
                        }
                    }
                }
            }
            
            // Update location while dragging (use cached value)
            if dragActive && mouseIsDown {
                dragLocation = currentMouseLocation
                detectJiggle(currentLocation: currentMouseLocation)
                lastDragLocation = currentMouseLocation
            }
            
            // Detect drag END
            if !mouseIsDown && dragActive {
                dragActive = false
                isDragging = false
                dragEndNotified = true
                
                // Notify controller that drag ended
                FloatingBasketWindowController.shared.onDragEnded()
                
                resetJiggle()
            }
        }
    }
    
    private func detectJiggle(currentLocation: CGPoint) {
        let dx = currentLocation.x - lastDragLocation.x
        let dy = currentLocation.y - lastDragLocation.y
        let magnitude = sqrt(dx * dx + dy * dy)
        
        guard magnitude > 5 else { return }
        
        let currentDirection = CGPoint(x: dx / magnitude, y: dy / magnitude)
        
        if lastDragDirection != .zero {
            let dot = currentDirection.x * lastDragDirection.x + currentDirection.y * lastDragDirection.y
            
            if dot < -0.3 {
                let now = Date()
                directionChanges.append(now)
                directionChanges = directionChanges.filter { now.timeIntervalSince($0) < jiggleTimeWindow }
                
                if directionChanges.count >= jiggleThreshold && !jiggleNotified {
                    didJiggle = true
                    jiggleNotified = true
                    
                    // Allow re-notifying after a delay (to move basket)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.jiggleNotified = false
                    }
                    
                    // Use async to avoid blocking the timer
                    DispatchQueue.main.async {
                        // Check if basket is enabled before showing
                        let enabled = UserDefaults.standard.bool(forKey: "enableFloatingBasket")
                        if enabled || UserDefaults.standard.object(forKey: "enableFloatingBasket") == nil {
                            FloatingBasketWindowController.shared.onJiggleDetected()
                        }
                    }
                }
            }
        }
        
        lastDragDirection = currentDirection
    }
}
