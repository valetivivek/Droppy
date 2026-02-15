//
//  MenuBarFloatingModels.swift
//  Droppy
//
//  Models and helpers for Menu Bar Manager's always-hidden floating bar.
//

import AppKit
import ApplicationServices
import CoreGraphics

struct MenuBarFloatingItemSnapshot: Identifiable {
    let id: String
    let axElement: AXUIElement
    let quartzFrame: CGRect
    let appKitFrame: CGRect
    let ownerBundleID: String
    let axIdentifier: String?
    let statusItemIndex: Int?
    let title: String?
    let detail: String?
    let icon: NSImage?

    var displayName: String {
        if let title, !title.isEmpty {
            return title
        }
        if let detail, !detail.isEmpty {
            return detail
        }
        return ownerBundleID
    }
}

enum MenuBarFloatingIconLayout {
    static func nativeIconSize(for item: MenuBarFloatingItemSnapshot) -> CGSize {
        if let icon = item.icon {
            let size = icon.size
            if size.width > 1, size.height > 1 {
                return CGSize(
                    width: max(10, min(72, round(size.width))),
                    height: max(14, min(32, round(size.height)))
                )
            }
        }

        let frame = item.quartzFrame
        if frame.width > 1, frame.height > 1 {
            return CGSize(
                width: max(10, min(72, round(frame.width))),
                height: max(14, min(32, round(frame.height)))
            )
        }

        let fallbackHeight = max(14, min(32, round(NSStatusBar.system.thickness)))
        return CGSize(width: fallbackHeight, height: fallbackHeight)
    }
}

enum MenuBarAXTools {
    static func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> AnyObject? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard status == .success, let value else {
            return nil
        }
        return value as AnyObject
    }

    static func copyString(_ element: AXUIElement, _ attribute: CFString) -> String? {
        copyAttribute(element, attribute) as? String
    }

    static func copyChildren(_ element: AXUIElement) -> [AXUIElement] {
        (copyAttribute(element, kAXChildrenAttribute as CFString) as? [AXUIElement]) ?? []
    }

    static func copyPoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        guard let rawValue = copyAttribute(element, attribute),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }
        let value = rawValue as! AXValue
        guard
              AXValueGetType(value) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value, .cgPoint, &point)
        return point
    }

    static func copySize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        guard let rawValue = copyAttribute(element, attribute),
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }
        let value = rawValue as! AXValue
        guard
              AXValueGetType(value) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        AXValueGetValue(value, .cgSize, &size)
        return size
    }

    static func copyFrameQuartz(_ element: AXUIElement) -> CGRect? {
        guard let position = copyPoint(element, kAXPositionAttribute as CFString),
              let size = copySize(element, kAXSizeAttribute as CFString) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    static func availableActions(for element: AXUIElement) -> [String] {
        var actionNames: CFArray?
        guard AXUIElementCopyActionNames(element, &actionNames) == .success,
              let actionNames = actionNames as? [String] else {
            return []
        }
        return actionNames
    }

    static func bestMenuBarAction(for element: AXUIElement) -> CFString {
        let actions = availableActions(for: element)
        if actions.contains(kAXShowMenuAction as String) {
            return kAXShowMenuAction as CFString
        }
        return kAXPressAction as CFString
    }

    static func performAction(_ element: AXUIElement, _ action: CFString) -> Bool {
        AXUIElementPerformAction(element, action) == .success
    }
}

enum MenuBarFloatingCoordinateConverter {
    static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func displayBounds(of screen: NSScreen) -> CGRect? {
        guard let id = displayID(for: screen) else {
            return nil
        }
        return CGDisplayBounds(id)
    }

    static func screenContaining(quartzPoint: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { screen in
            guard let bounds = displayBounds(of: screen) else {
                return false
            }
            return bounds.contains(quartzPoint)
        })
    }

    static func quartzToAppKit(_ quartzRect: CGRect) -> CGRect {
        let point = CGPoint(x: quartzRect.midX, y: quartzRect.midY)
        guard let screen = screenContaining(quartzPoint: point) ?? NSScreen.main,
              let displayBounds = displayBounds(of: screen) else {
            let mainHeight = NSScreen.main?.frame.height ?? 0
            return CGRect(
                x: quartzRect.origin.x,
                y: mainHeight - quartzRect.origin.y - quartzRect.height,
                width: quartzRect.width,
                height: quartzRect.height
            )
        }

        let localX = quartzRect.origin.x - displayBounds.origin.x
        let localY = quartzRect.origin.y - displayBounds.origin.y
        let flippedLocalY = displayBounds.height - localY - quartzRect.height

        return CGRect(
            x: screen.frame.origin.x + localX,
            y: screen.frame.origin.y + flippedLocalY,
            width: quartzRect.width,
            height: quartzRect.height
        )
    }

    static func appKitToQuartz(_ appKitRect: CGRect) -> CGRect {
        let point = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main,
              let displayBounds = displayBounds(of: screen) else {
            let mainHeight = NSScreen.main?.frame.height ?? 0
            return CGRect(
                x: appKitRect.origin.x,
                y: mainHeight - appKitRect.origin.y - appKitRect.height,
                width: appKitRect.width,
                height: appKitRect.height
            )
        }

        let localX = appKitRect.origin.x - screen.frame.origin.x
        let localY = appKitRect.origin.y - screen.frame.origin.y
        let flippedLocalY = displayBounds.height - localY - appKitRect.height

        return CGRect(
            x: displayBounds.origin.x + localX,
            y: displayBounds.origin.y + flippedLocalY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}
