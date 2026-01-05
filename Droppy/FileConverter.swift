//
//  FileConverter.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Represents a file format that can be converted to
enum ConversionFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png = "PNG"
    case pdf = "PDF"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }
    
    var bitmapType: NSBitmapImageRep.FileType? {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .pdf: return nil // PDF uses Gotenberg, not bitmap
        }
    }
    
    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .pdf: return "PDF"
        }
    }
    
    var icon: String {
        switch self {
        case .jpeg: return "photo"
        case .png: return "photo.fill"
        case .pdf: return "doc.richtext"
        }
    }
}

/// A conversion option presented in the context menu
struct ConversionOption: Identifiable {
    let id = UUID()
    let format: ConversionFormat
    
    var displayName: String { format.displayName }
    var icon: String { format.icon }
}

/// Utility class for converting files between formats using native macOS APIs and Cloudmersive
class FileConverter {
    
    /// Cloudmersive API key - Free tier: 800 calls/month
    /// Get your own key at: https://account.cloudmersive.com/signup
    static let cloudmersiveAPIKey = "0d34f6fa-02f6-4ffc-a000-a1319d54d6eb"
    
    /// Cloudmersive API base URL
    static let cloudmersiveBaseURL = "https://api.cloudmersive.com"
    
    /// Local Gotenberg URL (fallback if available)
    static let gotenbergURL = "http://localhost:3001"
    
    // MARK: - Available Conversions
    
    /// Returns available conversion options for a given file type
    static func availableConversions(for fileType: UTType?) -> [ConversionOption] {
        guard let fileType = fileType else { return [] }
        
        var options: [ConversionOption] = []
        
        // Image conversions
        if fileType.conforms(to: .image) {
            // If it's a PNG, offer JPEG
            if fileType.conforms(to: .png) {
                options.append(ConversionOption(format: .jpeg))
            }
            // If it's a JPEG, offer PNG
            else if fileType.conforms(to: .jpeg) {
                options.append(ConversionOption(format: .png))
            }
            // For other image formats (HEIC, TIFF, BMP, GIF), offer both
            else if fileType.conforms(to: .heic) ||
                    fileType.conforms(to: .tiff) ||
                    fileType.conforms(to: .bmp) ||
                    fileType.conforms(to: .gif) {
                options.append(ConversionOption(format: .jpeg))
                options.append(ConversionOption(format: .png))
            }
        }
        
        // Document to PDF conversions (via Cloudmersive API)
        // Word documents
        if fileType.conforms(to: UTType("org.openxmlformats.wordprocessingml.document") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.word.doc") ?? .data) ||
           fileType.identifier == "org.openxmlformats.wordprocessingml.document" ||
           fileType.identifier == "com.microsoft.word.doc" {
            options.append(ConversionOption(format: .pdf))
        }
        
        // Excel spreadsheets
        if fileType.conforms(to: UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.excel.xls") ?? .data) ||
           fileType.identifier == "org.openxmlformats.spreadsheetml.sheet" ||
           fileType.identifier == "com.microsoft.excel.xls" {
            options.append(ConversionOption(format: .pdf))
        }
        
        // PowerPoint presentations
        if fileType.conforms(to: UTType("org.openxmlformats.presentationml.presentation") ?? .data) ||
           fileType.conforms(to: UTType("com.microsoft.powerpoint.ppt") ?? .data) ||
           fileType.identifier == "org.openxmlformats.presentationml.presentation" ||
           fileType.identifier == "com.microsoft.powerpoint.ppt" {
            options.append(ConversionOption(format: .pdf))
        }
        
        return options
    }
    
    // MARK: - Conversion Methods
    
    /// Converts a file to the specified format
    /// Returns the URL of the converted file (in temp directory), or nil if conversion failed
    static func convert(_ url: URL, to format: ConversionFormat) async -> URL? {
        // Generate output URL in centrally managed temp directory
        let filename = url.deletingPathExtension().lastPathComponent + "." + format.fileExtension
        let finalURL = TemporaryFileManager.shared.temporaryFileURL(filename: filename)
        
        // Route to appropriate converter
        if format == .pdf {
            return await convertDocumentToPDF(from: url, to: finalURL)
        } else {
            return await convertImage(from: url, to: finalURL, format: format)
        }
    }
    
    /// Moves a converted file to the Downloads folder
    /// Returns the final URL in Downloads, or nil if move failed
    static func saveToDownloads(_ tempURL: URL) -> URL? {
        let fileManager = FileManager.default
        
        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("FileConverter: Could not find Downloads folder")
            return nil
        }
        
        let destinationURL = uniqueURL(for: downloadsURL.appendingPathComponent(tempURL.lastPathComponent))
        
        do {
            try fileManager.moveItem(at: tempURL, to: destinationURL)
            print("FileConverter: Saved to Downloads: \(destinationURL.lastPathComponent)")
            return destinationURL
        } catch {
            print("FileConverter: Failed to move to Downloads: \(error)")
            return nil
        }
    }
    
    // MARK: - Image Conversion
    
    private static func convertImage(from sourceURL: URL, to destinationURL: URL, format: ConversionFormat) async -> URL? {
        guard let image = NSImage(contentsOf: sourceURL) else {
            print("FileConverter: Failed to load image from \(sourceURL)")
            return nil
        }
        
        // Get the best representation
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            print("FileConverter: Failed to create bitmap representation")
            return nil
        }
        
        guard let bitmapType = format.bitmapType else {
            print("FileConverter: Format \(format.displayName) does not support bitmap conversion")
            return nil
        }
        
        // Set compression quality for JPEG
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        if format == .jpeg {
            properties[.compressionFactor] = 0.9 // High quality JPEG
        }
        
        // Convert to target format
        guard let outputData = bitmapRep.representation(using: bitmapType, properties: properties) else {
            print("FileConverter: Failed to convert to \(format.displayName)")
            return nil
        }
        
        // Write to file
        do {
            try outputData.write(to: destinationURL)
            print("FileConverter: Successfully converted to \(destinationURL.lastPathComponent)")
            return destinationURL
        } catch {
            print("FileConverter: Failed to write file: \(error)")
            return nil
        }
    }
    
    // MARK: - Document to PDF Conversion (via Cloudmersive API)
    
    private static func convertDocumentToPDF(from sourceURL: URL, to destinationURL: URL) async -> URL? {
        // Determine the correct endpoint based on file type
        let fileExtension = sourceURL.pathExtension.lowercased()
        let endpoint: String
        
        switch fileExtension {
        case "docx":
            endpoint = "/convert/docx/to/pdf"
        case "doc":
            endpoint = "/convert/doc/to/pdf"
        case "xlsx":
            endpoint = "/convert/xlsx/to/pdf"
        case "xls":
            endpoint = "/convert/xls/to/pdf"
        case "pptx":
            endpoint = "/convert/pptx/to/pdf"
        case "ppt":
            endpoint = "/convert/ppt/to/pdf"
        default:
            // Try generic office conversion
            endpoint = "/convert/autodetect/to/pdf"
        }
        
        guard let url = URL(string: "\(cloudmersiveBaseURL)\(endpoint)") else {
            print("FileConverter: Invalid Cloudmersive URL")
            return nil
        }
        
        // Read the source file
        guard let fileData = try? Data(contentsOf: sourceURL) else {
            print("FileConverter: Failed to read source file")
            return nil
        }
        
        // Create multipart form data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(cloudmersiveAPIKey, forHTTPHeaderField: "Apikey")
        request.timeoutInterval = 120 // Allow up to 120 seconds for cloud conversion
        
        // Build multipart body
        var body = Data()
        
        // Add the file
        let filename = sourceURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"inputFile\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Make the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("FileConverter: Invalid response from Cloudmersive")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("FileConverter: Cloudmersive returned status \(httpResponse.statusCode)")
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("FileConverter: Error: \(errorMessage)")
                }
                // Fall back to local Gotenberg if available
                return await convertDocumentToPDFViaGotenberg(from: sourceURL, to: destinationURL)
            }
            
            // Write the PDF to destination
            try data.write(to: destinationURL)
            print("FileConverter: Successfully converted to PDF via Cloudmersive")
            return destinationURL
            
        } catch {
            print("FileConverter: Cloudmersive request failed: \(error)")
            // Fall back to local Gotenberg if available
            return await convertDocumentToPDFViaGotenberg(from: sourceURL, to: destinationURL)
        }
    }
    
    // MARK: - Fallback: Local Gotenberg
    
    private static func convertDocumentToPDFViaGotenberg(from sourceURL: URL, to destinationURL: URL) async -> URL? {
        // Gotenberg LibreOffice endpoint for office documents
        guard let url = URL(string: "\(gotenbergURL)/forms/libreoffice/convert") else {
            print("FileConverter: Invalid Gotenberg URL")
            return nil
        }
        
        // Read the source file
        guard let fileData = try? Data(contentsOf: sourceURL) else {
            print("FileConverter: Failed to read source file")
            return nil
        }
        
        // Create multipart form data request
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        // Build multipart body
        var body = Data()
        
        // Add the file
        let filename = sourceURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Make the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("FileConverter: Invalid response from Gotenberg")
                return nil
            }
            
            guard httpResponse.statusCode == 200 else {
                print("FileConverter: Gotenberg returned status \(httpResponse.statusCode)")
                return nil
            }
            
            // Write the PDF to destination
            try data.write(to: destinationURL)
            print("FileConverter: Successfully converted to PDF via Gotenberg (fallback)")
            return destinationURL
            
        } catch {
            print("FileConverter: Gotenberg request failed: \(error)")
            return nil
        }
    }
    
    // MARK: - ZIP Creation
    
    /// Creates a ZIP archive from multiple files
    /// Returns the URL of the created ZIP file (in temp directory), or nil if creation failed
    static func createZIP(from items: [DroppedItem], archiveName: String? = nil) async -> URL? {
        guard !items.isEmpty else { return nil }
        
        let zipName = archiveName ?? "Archive"
        let zipFilename = zipName + ".zip"
        // Use central temp manager for the output ZIP
        let zipURL = TemporaryFileManager.shared.temporaryFileURL(filename: zipFilename)
        
        // Create a central temp directory for holding file copies
        guard let workDir = TemporaryFileManager.shared.createTemporaryDirectory(name: UUID().uuidString) else {
            print("FileConverter: Failed to create work directory for ZIP")
            return nil
        }
        
        // Copy files to work directory (handles files from different locations)
        var filenames: [String] = []
        for item in items {
            var destFilename = item.name
            var destURL = workDir.appendingPathComponent(destFilename)
            
            // Handle duplicate filenames within the archive
            var counter = 1
            while FileManager.default.fileExists(atPath: destURL.path) {
                let name = item.url.deletingPathExtension().lastPathComponent
                let ext = item.url.pathExtension
                destFilename = "\(name)_\(counter).\(ext)"
                destURL = workDir.appendingPathComponent(destFilename)
                counter += 1
            }
            
            do {
                try FileManager.default.copyItem(at: item.url, to: destURL)
                filenames.append(destFilename)
            } catch {
                print("FileConverter: Failed to copy file for ZIP: \(error)")
                // Continue with other files
            }
        }
        
        guard !filenames.isEmpty else {
            try? FileManager.default.removeItem(at: workDir)
            return nil
        }
        
        // Use macOS built-in zip command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = workDir
        process.arguments = ["-r", zipURL.path] + filenames
        
        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Cleanup work directory
            try? FileManager.default.removeItem(at: workDir)
            
            if process.terminationStatus == 0 {
                print("FileConverter: Successfully created ZIP: \(zipURL.lastPathComponent)")
                return zipURL
            } else {
                print("FileConverter: zip command failed with status \(process.terminationStatus)")
            }
        } catch {
            print("FileConverter: Failed to run zip command: \(error)")
            try? FileManager.default.removeItem(at: workDir)
        }
        
        return nil
    }
    
    // MARK: - Helpers
    
    /// Generates a unique URL if the file already exists
    private static func uniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: url.path) {
            return url
        }
        
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newURL = url
        
        while fileManager.fileExists(atPath: newURL.path) {
            let newFilename = "\(filename)_\(counter).\(ext)"
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        }
        
        return newURL
    }
}
