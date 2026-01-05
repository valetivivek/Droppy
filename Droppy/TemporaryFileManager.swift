//
//  TemporaryFileManager.swift
//  Droppy
//
//  Created by Jordy Spruit on 05/01/2026.
//

import Foundation

/// Centralized manager for handling temporary files in Droppy.
/// Ensures all temp files are created in a dedicated subdirectory and can be cleaned up easily.
final class TemporaryFileManager {
    
    static let shared = TemporaryFileManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectoryName = "DroppyCache"
    
    private init() {
        // Ensure cache directory exists on startup
        createCacheDirectoryIfNeeded()
    }
    
    /// The base URL for Droppy's temporary cache
    private var cacheDirectoryURL: URL {
        return fileManager.temporaryDirectory.appendingPathComponent(cacheDirectoryName)
    }
    
    /// Ensures the cache directory exists
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("TemporaryFileManager: Failed to create cache directory: \(error)")
            }
        }
    }
    
    // MARK: - Public API
    
    /// Creates a unique temporary file URL with the given filename
    func temporaryFileURL(filename: String) -> URL {
        createCacheDirectoryIfNeeded()
        return uniqueURL(for: cacheDirectoryURL.appendingPathComponent(filename))
    }
    
    /// Creates a unique temporary directory for a batch of files
    func createTemporaryDirectory(name: String? = nil) -> URL? {
        createCacheDirectoryIfNeeded()
        
        let dirName = name ?? UUID().uuidString
        let url = uniqueURL(for: cacheDirectoryURL.appendingPathComponent(dirName))
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return url
        } catch {
            print("TemporaryFileManager: Failed to create specific temp directory: \(error)")
            return nil
        }
    }
    
    /// Cleans up the entire cache directory
    func cleanUp() {
        // Only run if the directory actually exists
        guard fileManager.fileExists(atPath: cacheDirectoryURL.path) else { return }
        
        print("TemporaryFileManager: Cleaning up cache...")
        
        do {
            // Remove the entire directory
            try fileManager.removeItem(at: cacheDirectoryURL)
            // Re-create it immediately for next use
            createCacheDirectoryIfNeeded()
        } catch {
            print("TemporaryFileManager: Failed to clean up cache: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func uniqueURL(for url: URL) -> URL {
        if !fileManager.fileExists(atPath: url.path) {
            return url
        }
        
        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        
        var counter = 1
        var newURL = url
        
        while fileManager.fileExists(atPath: newURL.path) {
            let newFilename = "\(filename)_\(counter)" + (ext.isEmpty ? "" : ".\(ext)")
            newURL = directory.appendingPathComponent(newFilename)
            counter += 1
        }
        
        return newURL
    }
}
