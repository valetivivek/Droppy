//
//  MenuBarFloatingScanner.swift
//  Droppy
//
//  Accessibility-based scanner for menu bar items used by the always-hidden bar.
//

import AppKit
import ApplicationServices
import CoreGraphics

final class MenuBarFloatingScanner {
    enum Owner: String, CaseIterable {
        case systemUIServer = "com.apple.systemuiserver"
        case controlCenter = "com.apple.controlcenter"
    }

    private struct Candidate {
        let identityBase: String
        let axElement: AXUIElement
        let quartzFrame: CGRect
        let appKitFrame: CGRect
        let ownerBundleID: String
        let axIdentifier: String?
        let statusItemIndex: Int?
        let title: String?
        let detail: String?
        let icon: NSImage?
    }

    private let excludedTitles: Set<String> = [
        "DroppyMBM_Icon",
        "DroppyMBM_Hidden",
        "DroppyMBM_AlwaysHidden",
    ]

    func scan(includeIcons: Bool, preferredOwnerBundleIDs: Set<String>? = nil) -> [MenuBarFloatingItemSnapshot] {
        var candidates = [Candidate]()
        candidates.reserveCapacity(64)

        for ownerBundleID in ownerBundleIDsToScan(preferredOwnerBundleIDs: preferredOwnerBundleIDs) {
            candidates.append(contentsOf: scanCandidates(ownerBundleID: ownerBundleID, includeIcons: includeIcons))
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            let delta = lhs.quartzFrame.minX - rhs.quartzFrame.minX
            if abs(delta) > 0.5 {
                return delta < 0
            }
            if lhs.ownerBundleID != rhs.ownerBundleID {
                return lhs.ownerBundleID < rhs.ownerBundleID
            }
            if lhs.statusItemIndex != rhs.statusItemIndex {
                return (lhs.statusItemIndex ?? Int.max) < (rhs.statusItemIndex ?? Int.max)
            }
            if lhs.axIdentifier != rhs.axIdentifier {
                return (lhs.axIdentifier ?? "") < (rhs.axIdentifier ?? "")
            }
            let lhsTitle = lhs.title ?? ""
            let rhsTitle = rhs.title ?? ""
            if lhsTitle != rhsTitle {
                return lhsTitle < rhsTitle
            }
            return (lhs.detail ?? "") < (rhs.detail ?? "")
        }

        var occurrenceByBase = [String: Int]()
        var snapshots = [MenuBarFloatingItemSnapshot]()
        snapshots.reserveCapacity(sortedCandidates.count)

        for candidate in sortedCandidates {
            let occurrence = occurrenceByBase[candidate.identityBase, default: 0]
            occurrenceByBase[candidate.identityBase] = occurrence + 1

            let id: String
            if occurrence == 0 {
                id = candidate.identityBase
            } else {
                id = "\(candidate.identityBase)#\(occurrence)"
            }

            snapshots.append(
                MenuBarFloatingItemSnapshot(
                    id: id,
                    axElement: candidate.axElement,
                    quartzFrame: candidate.quartzFrame,
                    appKitFrame: candidate.appKitFrame,
                    ownerBundleID: candidate.ownerBundleID,
                    axIdentifier: candidate.axIdentifier,
                    statusItemIndex: candidate.statusItemIndex,
                    title: candidate.title,
                    detail: candidate.detail,
                    icon: candidate.icon
                )
            )
        }

        return snapshots
    }

    private func scanCandidates(ownerBundleID: String, includeIcons: Bool) -> [Candidate] {
        guard let application = NSRunningApplication.runningApplications(withBundleIdentifier: ownerBundleID).first else {
            return []
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let menuBarRoots = menuBarRoots(for: appElement, ownerBundleID: ownerBundleID)
        guard !menuBarRoots.isEmpty else {
            return []
        }

        var scannedCandidates = [Candidate]()

        for menuBarRoot in menuBarRoots {
            let menuItems = collectMenuBarItems(from: menuBarRoot)
            for (index, element) in menuItems.enumerated() {
                guard let quartzFrame = MenuBarAXTools.copyFrameQuartz(element) else {
                    continue
                }

                guard isLikelyMenuBarExtra(quartzFrame: quartzFrame) else {
                    continue
                }
                if ownerBundleID == Bundle.main.bundleIdentifier,
                   isLikelyPrimaryAppMenuItem(quartzFrame: quartzFrame) {
                    continue
                }

                let title = normalizeText(MenuBarAXTools.copyString(element, kAXTitleAttribute as CFString))
                if let title, excludedTitles.contains(title) {
                    continue
                }

                let description = normalizeText(MenuBarAXTools.copyString(element, kAXDescriptionAttribute as CFString))
                let help = normalizeText(MenuBarAXTools.copyString(element, kAXHelpAttribute as CFString))
                let detail = description ?? help
                let identifier = normalizeText(MenuBarAXTools.copyString(element, kAXIdentifierAttribute as CFString))

                let icon: NSImage?
                if includeIcons {
                    if let captured = captureIcon(quartzRect: quartzFrame),
                              !isSuspiciousCapture(captured) {
                        icon = captured
                    } else {
                        icon = nil
                    }
                } else {
                    icon = nil
                }
                let appKitFrame = MenuBarFloatingCoordinateConverter.quartzToAppKit(quartzFrame)

                scannedCandidates.append(
                    Candidate(
                        identityBase: makeIdentityBase(
                            ownerBundleID: ownerBundleID,
                            title: title,
                            detail: detail,
                            identifier: identifier,
                            index: index
                        ),
                        axElement: element,
                        quartzFrame: quartzFrame,
                        appKitFrame: appKitFrame,
                        ownerBundleID: ownerBundleID,
                        axIdentifier: identifier,
                        statusItemIndex: index,
                        title: title,
                        detail: detail,
                        icon: icon
                    )
                )
            }
        }

        return scannedCandidates
    }

    private func menuBarRoots(for appElement: AXUIElement, ownerBundleID: String) -> [AXUIElement] {
        if let raw = MenuBarAXTools.copyAttribute(appElement, "AXExtrasMenuBar" as CFString),
           CFGetTypeID(raw) == AXUIElementGetTypeID() {
            return [unsafeDowncast(raw, to: AXUIElement.self)]
        }

        let isOwnAppBundle = Bundle.main.bundleIdentifier == ownerBundleID
        let allowFallbackMenuBar =
            ownerBundleID == Owner.systemUIServer.rawValue
            || ownerBundleID == Owner.controlCenter.rawValue
            || isOwnAppBundle
        guard allowFallbackMenuBar else {
            return []
        }

        if let raw = MenuBarAXTools.copyAttribute(appElement, kAXMenuBarAttribute as CFString),
           CFGetTypeID(raw) == AXUIElementGetTypeID() {
            return [unsafeDowncast(raw, to: AXUIElement.self)]
        }

        return []
    }

    private func collectMenuBarItems(from root: AXUIElement) -> [AXUIElement] {
        var items = [AXUIElement]()

        func visit(_ node: AXUIElement) {
            let role = MenuBarAXTools.copyString(node, kAXRoleAttribute as CFString) ?? ""
            if role == (kAXMenuBarItemRole as String) || role == "AXMenuBarItem" {
                items.append(node)
                return
            }

            for child in MenuBarAXTools.copyChildren(node) {
                visit(child)
            }
        }

        visit(root)
        return items
    }

    private func ownerBundleIDsToScan(preferredOwnerBundleIDs: Set<String>?) -> [String] {
        var ordered = [String]()
        var seen = Set<String>()

        for owner in Owner.allCases.map(\.rawValue) {
            if seen.insert(owner).inserted {
                ordered.append(owner)
            }
        }

        if let preferredOwnerBundleIDs, !preferredOwnerBundleIDs.isEmpty {
            for bundleID in preferredOwnerBundleIDs {
                if seen.insert(bundleID).inserted {
                    ordered.append(bundleID)
                }
            }
            return ordered
        }

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            if seen.insert(bundleID).inserted {
                ordered.append(bundleID)
            }
        }

        return ordered
    }

    private func normalizeText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func leadingToken(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let token = value
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let token, !token.isEmpty {
            return token
        }
        return value
    }

    private func makeIdentityBase(
        ownerBundleID: String,
        title: String?,
        detail: String?,
        identifier: String?,
        index: Int
    ) -> String {
        if let identifier, !identifier.isEmpty {
            return "\(ownerBundleID)::axid:\(identifier)"
        }

        if let moduleToken = canonicalModuleIdentityToken(
            ownerBundleID: ownerBundleID,
            title: title,
            detail: detail,
            identifier: identifier
        ) {
            return "\(ownerBundleID)::module:\(moduleToken)"
        }

        if let detailToken = leadingToken(detail), !detailToken.isEmpty {
            return "\(ownerBundleID)::detail:\(detailToken)"
        }

        if let titleToken = leadingToken(title), !titleToken.isEmpty {
            return "\(ownerBundleID)::title:\(titleToken)"
        }

        return "\(ownerBundleID)::statusItem:\(index)"
    }

    private func canonicalModuleIdentityToken(
        ownerBundleID: String,
        title: String?,
        detail: String?,
        identifier: String?
    ) -> String? {
        guard ownerBundleID == Owner.controlCenter.rawValue || ownerBundleID == Owner.systemUIServer.rawValue else {
            return nil
        }
        let haystack = [
            identifier?.lowercased(),
            title?.lowercased(),
            detail?.lowercased(),
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        if haystack.contains("now playing") {
            return "now-playing"
        }
        return nil
    }

    private func isLikelyMenuBarExtra(quartzFrame: CGRect) -> Bool {
        guard quartzFrame.width > 3,
              quartzFrame.height > 3,
              quartzFrame.width < 180,
              quartzFrame.height < 50 else {
            return false
        }
        return true
    }

    private func isLikelyPrimaryAppMenuItem(quartzFrame: CGRect) -> Bool {
        let midpoint = CGPoint(x: quartzFrame.midX, y: quartzFrame.midY)
        guard let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: midpoint),
              let bounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return false
        }
        return midpoint.x < bounds.midX
    }

    private func captureIcon(quartzRect: CGRect) -> NSImage? {
        let captureRect = quartzRect
        guard captureRect.width > 1, captureRect.height > 1 else {
            return nil
        }

        let center = CGPoint(x: captureRect.midX, y: captureRect.midY)
        guard let screen = MenuBarFloatingCoordinateConverter.screenContaining(quartzPoint: center),
              let displayID = MenuBarFloatingCoordinateConverter.displayID(for: screen),
              let displayBounds = MenuBarFloatingCoordinateConverter.displayBounds(of: screen) else {
            return nil
        }

        let localRect = CGRect(
            x: captureRect.origin.x - displayBounds.origin.x,
            y: captureRect.origin.y - displayBounds.origin.y,
            width: captureRect.width,
            height: captureRect.height
        )

        guard let image = CGDisplayCreateImage(displayID, rect: localRect) else {
            return nil
        }

        let cleanedImage = removeMenuBarBackground(from: image) ?? image

        return NSImage(
            cgImage: cleanedImage,
            size: NSSize(width: captureRect.width, height: captureRect.height)
        )
    }

    private func removeMenuBarBackground(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 2, height > 2 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let drawContext: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return image
        }

        drawContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let pixelCount = width * height
        let opaqueCount = stride(from: 0, to: pixels.count, by: 4).reduce(0) { partial, index in
            partial + (pixels[index + 3] > 250 ? 1 : 0)
        }
        guard Double(opaqueCount) / Double(max(pixelCount, 1)) > 0.9 else {
            return image
        }

        let border = max(1, min(2, min(width, height) / 5))
        var bgR: Double = 0
        var bgG: Double = 0
        var bgB: Double = 0
        var sampleCount = 0

        func samplePixel(x: Int, y: Int) {
            let idx = ((y * width) + x) * 4
            bgR += Double(pixels[idx])
            bgG += Double(pixels[idx + 1])
            bgB += Double(pixels[idx + 2])
            sampleCount += 1
        }

        for y in 0 ..< height {
            for x in 0 ..< width where x < border || x >= (width - border) || y < border || y >= (height - border) {
                samplePixel(x: x, y: y)
            }
        }
        guard sampleCount > 0 else { return image }

        bgR /= Double(sampleCount)
        bgG /= Double(sampleCount)
        bgB /= Double(sampleCount)

        var borderDistanceSum: Double = 0
        for y in 0 ..< height {
            for x in 0 ..< width where x < border || x >= (width - border) || y < border || y >= (height - border) {
                let idx = ((y * width) + x) * 4
                let dr = Double(pixels[idx]) - bgR
                let dg = Double(pixels[idx + 1]) - bgG
                let db = Double(pixels[idx + 2]) - bgB
                borderDistanceSum += (dr * dr) + (dg * dg) + (db * db)
            }
        }
        let borderVariance = borderDistanceSum / Double(sampleCount)
        let baseThresholdSquared: Double = 28.0 * 28.0
        let adaptiveThresholdSquared = min(
            54.0 * 54.0,
            max(baseThresholdSquared, (borderVariance * 2.2) + (14.0 * 14.0))
        )
        let interiorPocketThresholdSquared = min(62.0 * 62.0, adaptiveThresholdSquared * 1.12)

        var visited = [Bool](repeating: false, count: pixelCount)
        var queue = [(Int, Int)]()
        var queueIndex = 0

        func isBackgroundCandidate(x: Int, y: Int, thresholdSquared: Double) -> Bool {
            let idx = ((y * width) + x) * 4
            let alpha = pixels[idx + 3]
            if alpha < 6 { return true }
            let dr = Double(pixels[idx]) - bgR
            let dg = Double(pixels[idx + 1]) - bgG
            let db = Double(pixels[idx + 2]) - bgB
            return (dr * dr) + (dg * dg) + (db * db) <= thresholdSquared
        }

        func enqueueBorderPixel(x: Int, y: Int) {
            let flatIndex = (y * width) + x
            guard !visited[flatIndex] else { return }
            guard isBackgroundCandidate(x: x, y: y, thresholdSquared: adaptiveThresholdSquared) else { return }
            visited[flatIndex] = true
            queue.append((x, y))
        }

        for x in 0 ..< width {
            enqueueBorderPixel(x: x, y: 0)
            enqueueBorderPixel(x: x, y: height - 1)
        }
        for y in 0 ..< height {
            enqueueBorderPixel(x: 0, y: y)
            enqueueBorderPixel(x: width - 1, y: y)
        }

        while queueIndex < queue.count {
            let (x, y) = queue[queueIndex]
            queueIndex += 1

            let idx = ((y * width) + x) * 4
            pixels[idx] = 0
            pixels[idx + 1] = 0
            pixels[idx + 2] = 0
            pixels[idx + 3] = 0

            let neighbors = [
                (x + 1, y),
                (x - 1, y),
                (x, y + 1),
                (x, y - 1),
            ]

            for (nx, ny) in neighbors {
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let flatIndex = (ny * width) + nx
                guard !visited[flatIndex] else { continue }
                guard isBackgroundCandidate(x: nx, y: ny, thresholdSquared: adaptiveThresholdSquared) else { continue }
                visited[flatIndex] = true
                queue.append((nx, ny))
            }
        }

        // Remove enclosed background pockets (e.g. ring/circle interiors) that don't touch borders.
        for y in 0 ..< height {
            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                guard pixels[idx + 3] > 18 else { continue }
                guard isBackgroundCandidate(x: x, y: y, thresholdSquared: interiorPocketThresholdSquared) else { continue }
                pixels[idx] = 0
                pixels[idx + 1] = 0
                pixels[idx + 2] = 0
                pixels[idx + 3] = 0
            }
        }

        func clearRowIfLikelySeparatorArtifact(_ y: Int) {
            guard y >= 0, y < height else { return }

            var opaque = 0
            var sumR: Double = 0
            var sumG: Double = 0
            var sumB: Double = 0

            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                let alpha = pixels[idx + 3]
                if alpha <= 18 { continue }
                opaque += 1
                sumR += Double(pixels[idx])
                sumG += Double(pixels[idx + 1])
                sumB += Double(pixels[idx + 2])
            }

            let coverage = Double(opaque) / Double(max(width, 1))
            guard opaque > 0, coverage >= 0.48 else { return }

            let meanR = sumR / Double(opaque)
            let meanG = sumG / Double(opaque)
            let meanB = sumB / Double(opaque)
            let luminance = (meanR * 0.2126) + (meanG * 0.7152) + (meanB * 0.0722)

            var varianceSum: Double = 0
            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                let alpha = pixels[idx + 3]
                if alpha <= 18 { continue }
                let dr = Double(pixels[idx]) - meanR
                let dg = Double(pixels[idx + 1]) - meanG
                let db = Double(pixels[idx + 2]) - meanB
                varianceSum += (dr * dr) + (dg * dg) + (db * db)
            }
            let variance = varianceSum / Double(max(opaque, 1))

            // Thin, flat, mostly monochrome rows at extreme edges are almost always menu-bar border captures.
            if variance <= (18.0 * 18.0), luminance <= 210 {
                for x in 0 ..< width {
                    let idx = ((y * width) + x) * 4
                    pixels[idx] = 0
                    pixels[idx + 1] = 0
                    pixels[idx + 2] = 0
                    pixels[idx + 3] = 0
                }
            }
        }

        clearRowIfLikelySeparatorArtifact(0)
        clearRowIfLikelySeparatorArtifact(1)
        clearRowIfLikelySeparatorArtifact(height - 2)
        clearRowIfLikelySeparatorArtifact(height - 1)

        let foregroundCount = stride(from: 0, to: pixels.count, by: 4).reduce(0) { partial, index in
            partial + (pixels[index + 3] > 18 ? 1 : 0)
        }
        guard foregroundCount >= max(8, pixelCount / 60) else {
            return image
        }

        return pixels.withUnsafeMutableBytes {
            guard let baseAddress = $0.baseAddress else { return nil }
            guard let outputContext = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return nil
            }
            return outputContext.makeImage()
        }
    }

    private func isSuspiciousCapture(_ image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else {
            return true
        }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return true }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context: CGContext = pixels.withUnsafeMutableBytes({ rawBufferPointer -> CGContext? in
            guard let baseAddress = rawBufferPointer.baseAddress else { return nil }
            return CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        }) else {
            return true
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var foregroundCount = 0
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0 ..< height {
            for x in 0 ..< width {
                let idx = ((y * width) + x) * 4
                if pixels[idx + 3] > 18 {
                    foregroundCount += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard foregroundCount >= max(8, (width * height) / 80) else {
            return true
        }

        let bboxWidth = max(1, maxX - minX + 1)
        let bboxHeight = max(1, maxY - minY + 1)
        let widthRatio = Double(bboxWidth) / Double(width)
        let heightRatio = Double(bboxHeight) / Double(height)
        let areaRatio = Double(foregroundCount) / Double(width * height)
        let edgeCount = max((width * 2) + (max(0, height - 2) * 2), 1)
        var edgeOpaqueCount = 0

        if height > 0 {
            for x in 0 ..< width {
                let topIdx = x * 4
                if pixels[topIdx + 3] > 18 {
                    edgeOpaqueCount += 1
                }
                if height > 1 {
                    let bottomIdx = (((height - 1) * width) + x) * 4
                    if pixels[bottomIdx + 3] > 18 {
                        edgeOpaqueCount += 1
                    }
                }
            }
        }

        if width > 1, height > 2 {
            for y in 1 ..< (height - 1) {
                let leftIdx = ((y * width) * 4)
                if pixels[leftIdx + 3] > 18 {
                    edgeOpaqueCount += 1
                }
                let rightIdx = (((y * width) + (width - 1)) * 4)
                if pixels[rightIdx + 3] > 18 {
                    edgeOpaqueCount += 1
                }
            }
        }
        let edgeOpaqueRatio = Double(edgeOpaqueCount) / Double(edgeCount)

        if widthRatio < 0.14 || heightRatio < 0.14 {
            return true
        }
        if widthRatio > 0.995 && heightRatio > 0.995 && areaRatio > 0.9 {
            return true
        }
        if areaRatio < 0.04 {
            return true
        }
        if areaRatio > 0.92 {
            return true
        }
        if edgeOpaqueRatio > 0.78 {
            return true
        }
        return false
    }

}
