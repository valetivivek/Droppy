//
//  MenuBarItem.swift
//  Droppy
//
//  Model for menu bar items using Ice's approach with private APIs.
//  Uses CGSGetProcessMenuBarWindowList to get ALL menu bar items.
//

import Cocoa

/// Represents a menu bar status item window
struct MenuBarItem: Identifiable, Equatable, Hashable {
    /// The window identifier for this item
    let windowID: CGWindowID
    
    /// The title of the window (if any)
    let title: String?
    
    /// The owning application's name
    let ownerName: String
    
    /// The owning application's PID
    let ownerPID: pid_t
    
    /// The frame of the item in screen coordinates (from CGSGetScreenRectForWindow)
    let frame: CGRect
    
    /// The owning application's bundle identifier
    let bundleIdentifier: String?
    
    // MARK: - Identifiable
    
    var id: CGWindowID { windowID }
    
    // MARK: - Computed Properties
    
    /// Display name for the item - follows Ice's naming logic
    var displayName: String {
        // Handle Control Center special titles like Ice does
        if bundleIdentifier == "com.apple.controlcenter" {
            switch title {
            case "AccessibilityShortcuts": return "Accessibility Shortcuts"
            case "BentoBox": return "Control Centre"
            case "FocusModes": return "Focus"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "NowPlaying": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "StageManager": return "Stage Manager"
            case "UserSwitcher": return "Fast User Switching"
            case "WiFi": return "Wi-Fi"
            default: return title ?? ownerName
            }
        }
        
        // Handle SystemUIServer special titles
        if bundleIdentifier == "com.apple.systemuiserver" {
            switch title {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                break
            }
        }
        
        // Default: use owner name or title
        return ownerName.isEmpty ? (title ?? "Unknown") : ownerName
    }
    
    /// The owning application
    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }
    
    // MARK: - Static Methods
    
    /// Gets all menu bar items using CGSGetProcessMenuBarWindowList
    /// This is the CORRECT way to get all menu bar items including system items
    static func getMenuBarItems(onScreenOnly: Bool = true, activeSpaceOnly: Bool = true) -> [MenuBarItem] {
        // Step 1: Get all menu bar window IDs via private API
        let menuBarWindowIDs = WindowServer.getMenuBarWindowList()
        
        print("[MenuBarItem] CGSGetProcessMenuBarWindowList returned \(menuBarWindowIDs.count) windows")
        
        // Step 2: For each window ID, get frame and info
        var items: [MenuBarItem] = []
        
        // Get window info for all windows to match with our menu bar window IDs
        guard let allWindowInfo = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            print("[MenuBarItem] CGWindowListCopyWindowInfo failed")
            return []
        }
        
        // Create a lookup dictionary by window ID
        var windowInfoByID: [CGWindowID: [String: Any]] = [:]
        for info in allWindowInfo {
            if let windowID = info[kCGWindowNumber as String] as? CGWindowID {
                windowInfoByID[windowID] = info
            }
        }
        
        for windowID in menuBarWindowIDs {
            // Get accurate frame from private API
            guard let frame = WindowServer.getWindowFrame(windowID: windowID) else {
                continue
            }
            
            // Skip tiny/invalid windows
            if frame.width < 5 || frame.height < 5 {
                continue
            }
            
            // Get window info for this ID
            guard let info = windowInfoByID[windowID] else {
                continue
            }
            
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            let title = info[kCGWindowName as String] as? String
            let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? false
            
            // Skip our own items
            if ownerName == "Droppy" {
                continue
            }
            
            // Apply onScreenOnly filter
            if onScreenOnly && !isOnScreen {
                continue
            }
            
            // Get bundle identifier from running application
            let bundleID = NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier
            
            let item = MenuBarItem(
                windowID: windowID,
                title: title,
                ownerName: ownerName,
                ownerPID: ownerPID,
                frame: frame,
                bundleIdentifier: bundleID
            )
            
            print("[MenuBarItem] Found: \(item.displayName) at x=\(Int(frame.minX)) w=\(Int(frame.width))")
            items.append(item)
        }
        
        print("[MenuBarItem] Returning \(items.count) menu bar items")
        
        // Sort by X position (right to left in menu bar)
        return items.sorted { $0.frame.minX > $1.frame.minX }
    }
    
    /// Gets the current frame of a menu bar item by window ID
    static func getCurrentFrame(for windowID: CGWindowID) -> CGRect? {
        WindowServer.getWindowFrame(windowID: windowID)
    }
}

// MARK: - MenuBarItemInfo

/// Lightweight identifier for a menu bar item (used as dictionary key)
struct MenuBarItemInfo: Hashable, Codable {
    let windowID: CGWindowID
    let ownerName: String
    let ownerPID: pid_t
    
    init(item: MenuBarItem) {
        self.windowID = item.windowID
        self.ownerName = item.ownerName
        self.ownerPID = item.ownerPID
    }
    
    init(windowID: CGWindowID, ownerName: String, ownerPID: pid_t) {
        self.windowID = windowID
        self.ownerName = ownerName
        self.ownerPID = ownerPID
    }
}

extension MenuBarItem {
    /// Creates an info struct for this item
    var info: MenuBarItemInfo {
        MenuBarItemInfo(item: self)
    }
}
