//
//  DroppyQuickshare.swift
//  Droppy
//
//  Shared Quickshare logic for uploading files and getting shareable links
//  Can be called from context menus, quick action buttons, etc.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Droppy Quickshare - uploads files to 0x0.st and gets shareable links
enum DroppyQuickshare {
    private enum UploadTarget {
        case link(URL)
        case files(fileURLs: [URL], remoteURLs: [URL])
    }

    private enum UploadFailure: LocalizedError {
        case message(String)

        var errorDescription: String? {
            switch self {
            case .message(let message):
                return message
            }
        }
    }
    
    /// Share files/links via Droppy Quickshare
    /// Multiple files are automatically zipped into a single archive
    static func share(urls: [URL], completion: (() -> Void)? = nil) {
        guard !ExtensionType.quickshare.isRemoved else { return }
        guard !urls.isEmpty else { return }
        guard !DroppyState.shared.isSharingInProgress else { return }

        let fileURLs = urls.filter(\.isFileURL)
        let remoteURLs = urls.filter { isSupportedRemoteURL($0) }
        let itemCount = fileURLs.count + remoteURLs.count

        guard itemCount > 0 else { return }

        let uploadTarget: UploadTarget
        if fileURLs.isEmpty && remoteURLs.count == 1 {
            uploadTarget = .link(remoteURLs[0])
        } else {
            uploadTarget = .files(fileURLs: fileURLs, remoteURLs: remoteURLs)
        }

        if shouldRequireUploadConfirmation() && !confirmUpload(fileURLs: fileURLs, remoteURLs: remoteURLs) {
            return
        }

        DroppyState.shared.isSharingInProgress = true
        DroppyState.shared.quickShareStatus = .uploading

        // Determine display filename for progress window
        let initialDisplayFilename: String
        switch uploadTarget {
        case .link(let url):
            initialDisplayFilename = url.absoluteString
        case .files:
            let hasDirectoryInput = fileURLs.contains {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }
            if fileURLs.count > 1 || hasDirectoryInput || (!fileURLs.isEmpty && !remoteURLs.isEmpty) {
                initialDisplayFilename = "Droppy Share (\(itemCount) items).zip"
            } else if remoteURLs.count > 1 {
                initialDisplayFilename = "Droppy Share (\(remoteURLs.count) links).txt"
            } else if let onlyFileURL = fileURLs.first {
                initialDisplayFilename = onlyFileURL.lastPathComponent
            } else {
                initialDisplayFilename = "Droppy Share (Links).txt"
            }
        }

        // Show progress window IMMEDIATELY so user knows upload is in progress
        DispatchQueue.main.async {
            QuickShareSuccessWindowController.showUploading(filename: initialDisplayFilename, fileCount: itemCount)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let thumbnailData: Data? = fileURLs.first.flatMap { QuickshareItem.generateThumbnail(from: $0) }

            switch uploadTarget {
            case .link(let url):
                let uploadResult = uploadURLTo0x0(remoteURL: url)
                completeUpload(
                    uploadResult,
                    displayFilename: url.absoluteString,
                    itemCount: 1,
                    thumbnailData: nil,
                    completion: completion
                )
            case .files(let fileURLs, let remoteURLs):
                var uploadSources = fileURLs
                var temporaryURLsToCleanup: [URL] = []

                if !remoteURLs.isEmpty {
                    guard let linksFileURL = createLinksFile(from: remoteURLs) else {
                        completeUpload(
                            .failure(.message("Could not prepare links for upload.")),
                            displayFilename: initialDisplayFilename,
                            itemCount: itemCount,
                            thumbnailData: thumbnailData,
                            completion: completion
                        )
                        return
                    }
                    uploadSources.append(linksFileURL)
                    temporaryURLsToCleanup.append(linksFileURL)
                }

                guard !uploadSources.isEmpty else {
                    completeUpload(
                        .failure(.message("No valid items to upload.")),
                        displayFilename: initialDisplayFilename,
                        itemCount: itemCount,
                        thumbnailData: thumbnailData,
                        completion: completion
                    )
                    return
                }

                var uploadURL = uploadSources[0]
                var isTemporaryZip = false
                let isLinksOnlyUpload = fileURLs.isEmpty && !remoteURLs.isEmpty
                var finalDisplayFilename = isLinksOnlyUpload
                    ? "Droppy Share (\(remoteURLs.count) links).txt"
                    : uploadURL.lastPathComponent

                // 0x0.st accepts files, not directories. ZIP when multiple items OR any directory is included.
                let shouldZip = uploadSources.count > 1 || uploadSources.contains {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                }
                if shouldZip {
                    guard let zipURL = createZIP(from: uploadSources) else {
                        completeUpload(
                            .failure(.message("Failed to create archive for upload.")),
                            displayFilename: initialDisplayFilename,
                            itemCount: itemCount,
                            thumbnailData: thumbnailData,
                            completion: completion
                        )
                        return
                    }
                    uploadURL = zipURL
                    isTemporaryZip = true
                    finalDisplayFilename = "Droppy Share (\(itemCount) items).zip"
                }

                let uploadResult = uploadTo0x0(fileURL: uploadURL)

                if isTemporaryZip {
                    try? FileManager.default.removeItem(at: uploadURL)
                }
                for temporaryURL in temporaryURLsToCleanup {
                    try? FileManager.default.removeItem(at: temporaryURL)
                }

                completeUpload(
                    uploadResult,
                    displayFilename: finalDisplayFilename,
                    itemCount: itemCount,
                    thumbnailData: thumbnailData,
                    completion: completion
                )
            }
        }
    }
    
    private static func shouldRequireUploadConfirmation() -> Bool {
        UserDefaults.standard.preference(
            AppPreferenceKey.quickshareRequireUploadConfirmation,
            default: PreferenceDefault.quickshareRequireUploadConfirmation
        )
    }

    private static func confirmUpload(fileURLs: [URL], remoteURLs: [URL]) -> Bool {
        let itemCount = fileURLs.count + remoteURLs.count
        let showDialog: () -> Bool = {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Upload to Quickshare?"

            if itemCount == 1, fileURLs.count == 1 {
                alert.informativeText = "Do you want to upload \"\(fileURLs[0].lastPathComponent)\" and copy a shareable link?"
            } else if itemCount == 1, remoteURLs.count == 1 {
                alert.informativeText = "Do you want to upload this link and copy a shareable link?"
            } else {
                if !fileURLs.isEmpty && !remoteURLs.isEmpty {
                    alert.informativeText = "Do you want to upload \(itemCount) items (files and links) to Quickshare and copy a shareable link?"
                } else if fileURLs.isEmpty {
                    alert.informativeText = "Do you want to upload \(remoteURLs.count) links to Quickshare and copy a shareable link?"
                } else {
                    alert.informativeText = "Do you want to upload \(fileURLs.count) files to Quickshare and copy a shareable link?"
                }
            }
            alert.addButton(withTitle: "Upload")
            alert.addButton(withTitle: "Cancel")
            alert.buttons.first?.keyEquivalent = "\r"
            alert.buttons.last?.keyEquivalent = "\u{1b}"
            
            // Ensure confirmation appears above all Droppy windows (Clipboard/Basket/etc.).
            let alertWindow = alert.window
            let highestVisibleLevel = NSApp.windows
                .filter { $0.isVisible }
                .map { $0.level.rawValue }
                .max() ?? NSWindow.Level.normal.rawValue
            let desiredLevel = max(NSWindow.Level.modalPanel.rawValue, highestVisibleLevel + 1)
            alertWindow.level = NSWindow.Level(rawValue: desiredLevel)
            alertWindow.collectionBehavior.insert(.canJoinAllSpaces)
            alertWindow.collectionBehavior.insert(.fullScreenAuxiliary)
            NSApp.activate(ignoringOtherApps: true)
            alertWindow.orderFrontRegardless()
            alertWindow.makeKey()
            
            return alert.runModal() == .alertFirstButtonReturn
        }

        if Thread.isMainThread {
            return showDialog()
        }

        var confirmed = false
        DispatchQueue.main.sync {
            confirmed = showDialog()
        }
        return confirmed
    }
    
    // MARK: - Private Helpers
    
    /// Creates a ZIP archive from multiple files
    private static func createZIP(from urls: [URL]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let zipName = "Droppy Share (\(urls.count) items).zip"
        let zipURL = tempDir.appendingPathComponent(zipName)
        
        // Remove existing zip if any
        try? FileManager.default.removeItem(at: zipURL)
        
        // Create zip using Archive utility
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        
        // Copy files to temp dir first for clean paths
        let stagingDir = tempDir.appendingPathComponent("droppy_staging_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        var stagedFiles: [String] = []
        for url in urls {
            let destURL = stagingDir.appendingPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: destURL)
                stagedFiles.append(url.lastPathComponent)
            } catch {
                print("Failed to stage file for ZIP: \(error)")
            }
        }
        
        guard !stagedFiles.isEmpty else {
            try? FileManager.default.removeItem(at: stagingDir)
            return nil
        }
        
        process.currentDirectoryURL = stagingDir
        process.arguments = ["-r", zipURL.path] + stagedFiles
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Cleanup staging
            try? FileManager.default.removeItem(at: stagingDir)
            
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: zipURL.path) {
                return zipURL
            }
        } catch {
            print("ZIP creation failed: \(error)")
        }
        
        try? FileManager.default.removeItem(at: stagingDir)
        return nil
    }
    
    /// Upload result containing URL and management token
    struct UploadResult {
        let shareURL: String
        let token: String
        let fileSize: Int64
    }
    
    /// Uploads a file to 0x0.st and returns the shareable URL and management token
    private static func uploadTo0x0(fileURL: URL) -> Result<UploadResult, UploadFailure> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<UploadResult, UploadFailure> = .failure(.message("Upload failed. Please try again."))
        
        // Get file size for expiration calculation
        let fileSize: Int64 = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        
        // Create multipart form data request
        let url = URL(string: "https://0x0.st")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Droppy/1.0", forHTTPHeaderField: "User-Agent")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let filename = fileURL.lastPathComponent

        guard let multipartFileURL = createMultipartBodyFile(fileURL: fileURL, filename: filename, boundary: boundary) else {
            return .failure(.message("Could not prepare file for upload."))
        }
        defer { try? FileManager.default.removeItem(at: multipartFileURL) }

        guard let requestBody = try? Data(contentsOf: multipartFileURL, options: .mappedIfSafe) else {
            return .failure(.message("Could not read upload payload."))
        }
        request.setValue(String(requestBody.count), forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 300

        request.httpBody = requestBody
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("Upload error: \(error)")
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        result = .failure(.message("Upload timed out. Please try again."))
                    case .cancelled:
                        result = .failure(.message("Upload cancelled."))
                    case .notConnectedToInternet, .networkConnectionLost:
                        result = .failure(.message("No internet connection."))
                    default:
                        result = .failure(.message("Network error: \(urlError.localizedDescription)"))
                    }
                } else {
                    result = .failure(.message("Upload failed: \(error.localizedDescription)"))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(.message("Invalid server response."))
                return
            }

            let responseString = String(data: data ?? Data(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard (200...299).contains(httpResponse.statusCode) else {
                let serverMessage = responseString.isEmpty
                    ? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    : responseString
                result = .failure(.message("Upload failed (\(httpResponse.statusCode)): \(serverMessage)"))
                return
            }
            
            // Extract X-Token from response headers
            let token = httpResponse.value(forHTTPHeaderField: "X-Token") ?? ""
            if let shareURL = extractShareURL(from: responseString) {
                result = .success(UploadResult(shareURL: shareURL, token: token, fileSize: fileSize))
            } else {
                let raw = responseString.isEmpty ? "Invalid upload response." : responseString
                result = .failure(.message(raw))
            }
        }
        
        task.resume()
        if semaphore.wait(timeout: .now() + 330) == .timedOut {
            task.cancel()
            return .failure(.message("Upload timed out. Please try again."))
        }
        
        return result
    }

    /// Uploads a remote URL to 0x0.st and returns the shareable URL and management token
    private static func uploadURLTo0x0(remoteURL: URL) -> Result<UploadResult, UploadFailure> {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<UploadResult, UploadFailure> = .failure(.message("Upload failed. Please try again."))

        let url = URL(string: "https://0x0.st")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Droppy/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "url", value: remoteURL.absoluteString)]
        let requestBodyString = components.percentEncodedQuery ?? ""
        let requestBody = Data(requestBodyString.utf8)
        request.setValue(String(requestBody.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = requestBody

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                print("Upload error: \(error)")
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .timedOut:
                        result = .failure(.message("Upload timed out. Please try again."))
                    case .cancelled:
                        result = .failure(.message("Upload cancelled."))
                    case .notConnectedToInternet, .networkConnectionLost:
                        result = .failure(.message("No internet connection."))
                    default:
                        result = .failure(.message("Network error: \(urlError.localizedDescription)"))
                    }
                } else {
                    result = .failure(.message("Upload failed: \(error.localizedDescription)"))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(.message("Invalid server response."))
                return
            }

            let responseString = String(data: data ?? Data(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard (200...299).contains(httpResponse.statusCode) else {
                let serverMessage = responseString.isEmpty
                    ? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    : responseString
                result = .failure(.message("Upload failed (\(httpResponse.statusCode)): \(serverMessage)"))
                return
            }

            let token = httpResponse.value(forHTTPHeaderField: "X-Token") ?? ""
            if let shareURL = extractShareURL(from: responseString) {
                result = .success(UploadResult(shareURL: shareURL, token: token, fileSize: 0))
            } else {
                let raw = responseString.isEmpty ? "Invalid upload response." : responseString
                result = .failure(.message(raw))
            }
        }

        task.resume()
        if semaphore.wait(timeout: .now() + 330) == .timedOut {
            task.cancel()
            return .failure(.message("Upload timed out. Please try again."))
        }

        return result
    }

    /// Build multipart body as a temporary file to avoid loading large uploads fully in memory.
    private static func createMultipartBodyFile(fileURL: URL, filename: String, boundary: String) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("droppy_upload_\(UUID().uuidString).tmp")

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)

        guard let outputHandle = try? FileHandle(forWritingTo: tempURL),
              let inputHandle = try? FileHandle(forReadingFrom: fileURL) else {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }

        defer {
            outputHandle.closeFile()
            inputHandle.closeFile()
        }

        let sanitizedFilename = sanitizeMultipartFilename(filename)
        let contentType = inferredContentType(for: fileURL)
        let headerLines = [
            "--\(boundary)",
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(sanitizedFilename)\"",
            "Content-Type: \(contentType)",
            ""
        ]
        outputHandle.write(Data(headerLines.joined(separator: "\r\n").utf8))
        outputHandle.write(Data("\r\n".utf8))

        let chunkSize = 64 * 1024
        while true {
            let chunk = inputHandle.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            outputHandle.write(chunk)
        }

        let footer = "\r\n--\(boundary)--\r\n"
        outputHandle.write(Data(footer.utf8))

        return tempURL
    }

    private static func completeUpload(
        _ uploadResult: Result<UploadResult, UploadFailure>,
        displayFilename: String,
        itemCount: Int,
        thumbnailData: Data?,
        completion: (() -> Void)?
    ) {
        DispatchQueue.main.async {
            DroppyState.shared.isSharingInProgress = false

            switch uploadResult {
            case .success(let result):
                let clipboard = NSPasteboard.general
                clipboard.clearContents()
                clipboard.setString(result.shareURL, forType: .string)

                let quickshareItem = QuickshareItem(
                    filename: displayFilename,
                    shareURL: result.shareURL,
                    token: result.token,
                    fileSize: result.fileSize,
                    thumbnailData: thumbnailData,
                    itemCount: itemCount
                )
                QuickshareManager.shared.addItem(quickshareItem)

                DroppyState.shared.quickShareStatus = .success(urls: [result.shareURL])
                HapticFeedback.copy()
                QuickShareSuccessWindowController.updateToSuccess(shareURL: result.shareURL)
                completion?()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    DroppyState.shared.quickShareStatus = .idle
                }

            case .failure(let error):
                let message = error.errorDescription ?? "Upload failed. Please try again."
                DroppyState.shared.quickShareStatus = .failed
                QuickShareSuccessWindowController.updateToFailed(error: message)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    DroppyState.shared.quickShareStatus = .idle
                }
            }
        }
    }

    private static func extractShareURL(from response: String) -> String? {
        if response.hasPrefix("http://") || response.hasPrefix("https://") {
            return response
        }

        let separators = CharacterSet.whitespacesAndNewlines
        let tokens = response.components(separatedBy: separators).filter { !$0.isEmpty }
        return tokens.first(where: { $0.hasPrefix("http://") || $0.hasPrefix("https://") })
    }

    private static func sanitizeMultipartFilename(_ filename: String) -> String {
        let safe = filename.unicodeScalars.map { scalar -> Character in
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
            return allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let collapsed = String(safe).replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "._"))
        return trimmed.isEmpty ? "upload.bin" : trimmed
    }

    private static func inferredContentType(for fileURL: URL) -> String {
        guard let utType = UTType(filenameExtension: fileURL.pathExtension),
              let mime = utType.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mime
    }

    private static func createLinksFile(from urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Droppy Share Links \(UUID().uuidString).txt")

        let links = urls
            .map(\.absoluteString)
            .joined(separator: "\n")

        do {
            try links.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    private static func isSupportedRemoteURL(_ url: URL) -> Bool {
        guard !url.isFileURL, let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

}
