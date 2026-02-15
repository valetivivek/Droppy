//
//  MenuBarFloatingWindows.swift
//  Droppy
//
//  Window controllers used by the always-hidden floating bar.
//

import AppKit
import SwiftUI

private enum FloatingBarMetrics {
    static func slotWidth(for item: MenuBarFloatingItemSnapshot) -> CGFloat {
        MenuBarFloatingIconLayout.nativeIconSize(for: item).width + 8
    }

    static func contentWidth(for items: [MenuBarFloatingItemSnapshot]) -> CGFloat {
        items.reduce(0) { partial, item in
            partial + slotWidth(for: item)
        }
    }

    static func rowHeight(for items: [MenuBarFloatingItemSnapshot]) -> CGFloat {
        let maxIconHeight = items.map { MenuBarFloatingIconLayout.nativeIconSize(for: $0).height }.max() ?? NSStatusBar.system.thickness
        return max(28, maxIconHeight + 8)
    }
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 8
}

@MainActor
final class MenuBarMaskController {
    private var windowsByID: [String: NSWindow] = [:]
    private var preparedSnapshotByID: [String: NSImage] = [:]

    func prepareBackgroundSnapshots(for hiddenItems: [MenuBarFloatingItemSnapshot]) {
        let keepIDs = Set(hiddenItems.map(\.id))
        preparedSnapshotByID = preparedSnapshotByID.filter { keepIDs.contains($0.key) }

        for item in hiddenItems {
            guard preparedSnapshotByID[item.id] == nil else { continue }
            guard let snapshot = captureBackgroundSnapshot(for: item) else { continue }
            preparedSnapshotByID[item.id] = snapshot
        }
    }

    func clearPreparedSnapshots() {
        preparedSnapshotByID.removeAll()
    }

    func update(hiddenItems: [MenuBarFloatingItemSnapshot], usePreparedSnapshots: Bool) {
        let nextIDs = Set(hiddenItems.map(\.id))
        let currentIDs = Set(windowsByID.keys)

        for removedID in currentIDs.subtracting(nextIDs) {
            windowsByID[removedID]?.orderOut(nil)
            windowsByID.removeValue(forKey: removedID)
        }

        for item in hiddenItems {
            let window = windowsByID[item.id] ?? makeWindow()
            windowsByID[item.id] = window
            window.setFrame(item.appKitFrame, display: false)
            if usePreparedSnapshots {
                guard let snapshot = preparedSnapshotByID[item.id] else {
                    window.orderOut(nil)
                    continue
                }
                applySnapshot(snapshot, to: window)
            } else {
                applyMaterialMask(to: window)
            }
            window.orderFrontRegardless()
        }
    }

    func hideAll() {
        for window in windowsByID.values {
            window.orderOut(nil)
        }
    }

    func windowNumber(for id: String) -> Int? {
        windowsByID[id]?.windowNumber
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.ignoresMouseEvents = true
        applyMaterialMask(to: window)

        return window
    }

    private func applyMaterialMask(to window: NSWindow) {
        if let effect = window.contentView as? NSVisualEffectView {
            effect.frame = window.contentView?.bounds ?? .zero
            return
        }

        let effect = NSVisualEffectView(frame: .zero)
        effect.autoresizingMask = [.width, .height]
        effect.material = .titlebar
        effect.blendingMode = .withinWindow
        effect.state = .active
        window.contentView = effect
    }

    private func applySnapshot(_ snapshot: NSImage, to window: NSWindow) {
        if let imageView = window.contentView as? NSImageView {
            imageView.image = snapshot
            imageView.frame = window.contentView?.bounds ?? .zero
            return
        }

        let imageView = NSImageView(frame: .zero)
        imageView.autoresizingMask = [.width, .height]
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently
        imageView.image = snapshot
        window.contentView = imageView
    }

    private func captureBackgroundSnapshot(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        let quartzRect = item.quartzFrame
        guard quartzRect.width > 1, quartzRect.height > 1 else { return nil }

        let center = CGPoint(x: quartzRect.midX, y: quartzRect.midY)
        guard let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: center),
              let displayID = MenuBarFloatingCoordinateConverter.displayID(for: screen),
              let displayBounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return nil
        }

        let localRect = CGRect(
            x: quartzRect.origin.x - displayBounds.origin.x,
            y: quartzRect.origin.y - displayBounds.origin.y,
            width: quartzRect.width,
            height: quartzRect.height
        )
        guard let cgImage = CGDisplayCreateImage(displayID, rect: localRect) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: quartzRect.width, height: quartzRect.height)
        )
    }
}

@MainActor
final class MenuBarFloatingPanelController {
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<MenuBarFloatingBarView>?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func containsMouseLocation(_ point: CGPoint = NSEvent.mouseLocation) -> Bool {
        guard let panel, panel.isVisible else { return false }
        // Slightly expanded hit area keeps behavior stable near rounded edges.
        return panel.frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    func show(
        items: [MenuBarFloatingItemSnapshot],
        onPress: @escaping (MenuBarFloatingItemSnapshot) -> Void
    ) {
        if panel == nil {
            panel = makePanel()
        }

        let content = MenuBarFloatingBarView(items: items, onPress: onPress)
        if let hostingView {
            hostingView.rootView = content
        } else {
            let view = NSHostingView(rootView: content)
            view.translatesAutoresizingMaskIntoConstraints = false
            hostingView = view
            panel?.contentView = view
        }

        positionPanel(for: items)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        return panel
    }

    private func positionPanel(for items: [MenuBarFloatingItemSnapshot]) {
        guard let panel else { return }
        guard let screen = bestScreen(for: items) ?? NSScreen.main else { return }

        let contentWidth = FloatingBarMetrics.contentWidth(for: items)
        let width = max(
            140,
            min(
                screen.frame.width - 12,
                contentWidth + (FloatingBarMetrics.horizontalPadding * 2)
            )
        )
        let rowHeight = FloatingBarMetrics.rowHeight(for: items)
        let height = rowHeight + (FloatingBarMetrics.verticalPadding * 2)

        let menuBarHeight = NSStatusBar.system.thickness
        let originX = screen.frame.maxX - width - 8
        let originY = screen.frame.maxY - menuBarHeight - height - 10

        panel.setFrame(
            CGRect(
                x: originX,
                y: originY,
                width: width,
                height: height
            ),
            display: true
        )
    }

    private func bestScreen(for items: [MenuBarFloatingItemSnapshot]) -> NSScreen? {
        guard let rightMost = items.max(by: { $0.quartzFrame.maxX < $1.quartzFrame.maxX }) else {
            return nil
        }
        let point = CGPoint(x: rightMost.quartzFrame.midX, y: rightMost.quartzFrame.midY)
        return MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: point)
    }

    private final class FloatingPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
}

private struct MenuBarFloatingBarView: View {
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    let items: [MenuBarFloatingItemSnapshot]
    let onPress: (MenuBarFloatingItemSnapshot) -> Void

    private var rowHeight: CGFloat {
        FloatingBarMetrics.rowHeight(for: items)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    useTransparentBackground
                    ? AnyShapeStyle(.ultraThinMaterial)
                    : AdaptiveColors.panelBackgroundOpaqueStyle
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AdaptiveColors.overlayAuto(useTransparentBackground ? 0.2 : 0.1), lineWidth: 1)
                )

            HStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        onPress(item)
                    } label: {
                        let iconSize = MenuBarFloatingIconLayout.nativeIconSize(for: item)
                        let slotWidth = FloatingBarMetrics.slotWidth(for: item)
                        floatingIconView(for: item)
                        .frame(width: iconSize.width, height: iconSize.height)
                        .frame(width: slotWidth, height: rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, FloatingBarMetrics.horizontalPadding)
            .padding(.vertical, FloatingBarMetrics.verticalPadding)
        }
    }

    @ViewBuilder
    private func floatingIconView(for item: MenuBarFloatingItemSnapshot) -> some View {
        if let icon = resolvedIcon(for: item) {
            if icon.isTemplate {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            }
        } else {
            Image(systemName: "app.dashed")
                .resizable()
                .scaledToFit()
        }
    }

    private func resolvedIcon(for item: MenuBarFloatingItemSnapshot) -> NSImage? {
        item.icon
    }

}
