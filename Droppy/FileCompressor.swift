//
//  FileCompressor.swift
//  Droppy
//
//  Created by Jordy Spruit on 03/01/2026.
//

import Foundation
import AppKit
@preconcurrency import AVFoundation
import UniformTypeIdentifiers
import PDFKit

/// Quality levels for compression
enum CompressionQuality: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    
    var displayName: String {
        switch self {
        case .low: return "Low (Smaller)"
        case .medium: return "Medium (Balanced)"
        case .high: return "High (Minimal Loss)"
        }
    }
    
    /// JPEG quality factor (0.0 - 1.0)
    var jpegQuality: CGFloat {
        switch self {
        case .low: return 0.3
        case .medium: return 0.6
        case .high: return 0.85
        }
    }
    
    /// Video export preset
    var videoPreset: String {
        switch self {
        case .low: return AVAssetExportPresetLowQuality
        case .medium: return AVAssetExportPresetMediumQuality
        case .high: return AVAssetExportPresetHighestQuality
        }
    }
}

/// Mode for compression operation
enum CompressionMode {
    case preset(CompressionQuality)
    case targetSize(bytes: Int64)
}

/// Service for compressing files (images, PDFs, videos)
class FileCompressor {
    static let shared = FileCompressor()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if a file can be compressed
    static func canCompress(url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .movie) || type.conforms(to: .video)
    }
    
    /// Check if a file type can be compressed
    static func canCompress(fileType: UTType?) -> Bool {
        guard let type = fileType else { return false }
        return type.conforms(to: .image) || type.conforms(to: .pdf) || type.conforms(to: .movie) || type.conforms(to: .video)
    }
    
    /// Compress a file with the specified mode
    /// Returns the URL of the compressed file, or nil on failure
    func compress(url: URL, mode: CompressionMode) async -> URL? {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        
        if type.conforms(to: .image) {
            return await compressImage(url: url, mode: mode)
        } else if type.conforms(to: .pdf) {
            return await compressPDF(url: url, mode: mode)
        } else if type.conforms(to: .movie) || type.conforms(to: .video) {
            return await compressVideo(url: url, mode: mode)
        }
        
        return nil
    }
    
    /// Get the file size in bytes
    static func fileSize(url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }
    
    /// Format bytes as human-readable string
    static func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Image Compression
    
    private func compressImage(url: URL, mode: CompressionMode) async -> URL? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let quality: CGFloat
        let targetBytes: Int64?
        
        switch mode {
        case .preset(let q):
            quality = q.jpegQuality
            targetBytes = nil
        case .targetSize(let bytes):
            quality = 0.8 // Starting point for iteration
            targetBytes = bytes
        }
        
        // Create output URL in temp directory
        let fileName = url.deletingPathExtension().lastPathComponent
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_compressed")
            .appendingPathExtension("jpg")
        
        // Get bitmap representation
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        if let targetBytes = targetBytes {
            // Iterative compression to reach target size
            return await compressImageToTargetSize(bitmap: bitmap, targetBytes: targetBytes, outputURL: outputURL)
        } else {
            // Direct compression with quality
            guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                return nil
            }
            
            do {
                try jpegData.write(to: outputURL)
                return outputURL
            } catch {
                print("Error writing compressed image: \(error)")
                return nil
            }
        }
    }
    
    private func compressImageToTargetSize(bitmap: NSBitmapImageRep, targetBytes: Int64, outputURL: URL) async -> URL? {
        var low: CGFloat = 0.01
        var high: CGFloat = 1.0
        var bestData: Data?
        var iterations = 0
        let maxIterations = 10
        
        while iterations < maxIterations && (high - low) > 0.02 {
            let mid = (low + high) / 2
            
            guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: mid]) else {
                break
            }
            
            let currentSize = Int64(jpegData.count)
            
            if currentSize <= targetBytes {
                // Size is acceptable, try higher quality
                bestData = jpegData
                low = mid
            } else {
                // Size too big, try lower quality
                high = mid
            }
            
            iterations += 1
        }
        
        // If we couldn't reach target, use the lowest quality
        if bestData == nil {
            bestData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.01])
        }
        
        guard let finalData = bestData else { return nil }
        
        do {
            try finalData.write(to: outputURL)
            return outputURL
        } catch {
            print("Error writing compressed image: \(error)")
            return nil
        }
    }
    
    // MARK: - PDF Compression
    
    private func compressPDF(url: URL, mode: CompressionMode) async -> URL? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        
        // Remove Quartz Filter logic (lines 208-231) to ensure we always use the robust image re-rendering path
        // which correctly handles page rotation and compression
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_compressed")
            .appendingPathExtension("pdf")
        
        return await compressPDFByRerendering(pdfDocument: pdfDocument, mode: mode, outputURL: outputURL)
    }



    private func compressVideoToTargetSize(asset: AVAsset, targetBytes: Int64, outputURL: URL) async -> URL? {
        // Use Apple's native fileLengthLimit for robust target sizing
        // This handles bitrate and resolution tradeoffs internally!
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHEVCHighestQuality) ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // This is the magic native property
        exportSession.fileLengthLimit = targetBytes
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            // Verify size (sometimes it overshoots slightly, but usually accurate)
            let actualSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
            print("Target: \(targetBytes), Actual: \(actualSize)")
            return outputURL
        } else {
            print("Video export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
            return nil
        }
    }
    
    // Deleted compressVideoWithBitrate as it's no longer needed
    
    private func compressPDFByRerendering(pdfDocument: PDFDocument, mode: CompressionMode, outputURL: URL) async -> URL? {
        // Determine JPEG quality and scale based on mode
        let jpegQuality: CGFloat
        let dpiScale: CGFloat
        switch mode {
        case .preset(let quality):
            switch quality {
            case .low:
                jpegQuality = 0.3
                dpiScale = 0.5  // 72 DPI
            case .medium:
                jpegQuality = 0.5
                dpiScale = 0.75 // 108 DPI
            case .high:
                jpegQuality = 0.7
                dpiScale = 1.0  // 144 DPI
            }
        case .targetSize:
            jpegQuality = 0.4
            dpiScale = 0.6
        }
        
        // Create new PDF from rendered page images
        guard let pdfData = CFDataCreateMutable(nil, 0) else { return nil }
        guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
        
        var mediaBox = CGRect.zero
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            
            // Get the VISUAL bounds (respecting rotation)
            // bounds(for:) returns the rotated bounds when rotation is applied
            let pageBounds = page.bounds(for: .cropBox)
            let rotation = page.rotation
            
            // Calculate visual dimensions after rotation
            let isRotated = rotation == 90 || rotation == 270
            let visualWidth = isRotated ? pageBounds.height : pageBounds.width
            let visualHeight = isRotated ? pageBounds.width : pageBounds.height
            
            // Render size (scaled for compression)
            let renderWidth = visualWidth * dpiScale
            let renderHeight = visualHeight * dpiScale
            
            // Render page to image using PDFPage's thumbnail method (handles rotation correctly)
            let pageImage = page.thumbnail(of: CGSize(width: renderWidth, height: renderHeight), for: .cropBox)
            
            // Convert to JPEG data
            guard let tiffData = pageImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else {
                continue
            }
            
            // Create image from JPEG data
            guard let jpegImage = NSImage(data: jpegData),
                  let cgImage = jpegImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }
            
            // Create PDF page with this image
            let pageMediaBox = CGRect(x: 0, y: 0, width: visualWidth, height: visualHeight)
            let pageInfo: [CFString: Any] = [kCGPDFContextMediaBox: pageMediaBox]
            pdfContext.beginPDFPage(pageInfo as CFDictionary)
            
            // Draw the JPEG image scaled to fill the page
            pdfContext.draw(cgImage, in: pageMediaBox)
            
            pdfContext.endPDFPage()
        }
        
        pdfContext.closePDF()
        
        // Write the PDF data
        let data = pdfData as Data
        do {
            try data.write(to: outputURL)
            return outputURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Video Compression
    
    private func compressVideo(url: URL, mode: CompressionMode) async -> URL? {
        let asset = AVAsset(url: url)
        
        let fileName = url.deletingPathExtension().lastPathComponent
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)_compressed")
            .appendingPathExtension("mp4")
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)
        
        switch mode {
        case .preset(let quality):
            return await compressVideoWithPreset(asset: asset, preset: quality.videoPreset, outputURL: outputURL)
        case .targetSize(let bytes):
            return await compressVideoToTargetSize(asset: asset, targetBytes: bytes, outputURL: outputURL)
        }
    }
    
    private func compressVideoWithPreset(asset: AVAsset, preset: String, outputURL: URL) async -> URL? {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if exportSession.status == .completed {
            return outputURL
        } else {
            print("Video export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
            return nil
        }
    }
}

// MARK: - Quartz Filter Helper
