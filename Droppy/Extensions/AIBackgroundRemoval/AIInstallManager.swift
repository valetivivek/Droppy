//
//  AIInstallManager.swift
//  Droppy
//
//  Created by Droppy on 11/01/2026.
//  Manages installation of AI background removal dependencies
//

import Foundation
import Combine

private nonisolated final class AIInstallOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func outputString() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}

private struct AIInstallProcessResult: Sendable {
    let status: Int32
    let output: String
}

/// Runs a process while continuously draining output to prevent deadlocks on verbose commands.
private func runAIInstallProcess(executable: String, arguments: [String]) async throws -> AIInstallProcessResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    let handle = outputPipe.fileHandleForReading
    let outputBuffer = AIInstallOutputBuffer()

    handle.readabilityHandler = { fileHandle in
        let chunk = fileHandle.availableData
        outputBuffer.append(chunk)
    }

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AIInstallProcessResult, Error>) in
        process.terminationHandler = { process in
            handle.readabilityHandler = nil
            let remainder = handle.readDataToEndOfFile()
            outputBuffer.append(remainder)
            let output = outputBuffer.outputString()

            continuation.resume(returning: AIInstallProcessResult(status: process.terminationStatus, output: output))
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            continuation.resume(throwing: error)
        }
    }
}

/// Manages the installation of Python transparent-background package
@MainActor
final class AIInstallManager: ObservableObject {
    static let shared = AIInstallManager()
    static let selectedPythonPathKey = "aiBackgroundRemovalPythonPath"
    
    @Published var isInstalled = false
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var installError: String?
    @Published private(set) var activePythonPath: String?
    @Published private(set) var detectedPythonPath: String?
    
    private let installedCacheKey = "aiBackgroundRemovalInstalled"
    
    private init() {
        // Load cached status immediately for instant UI response
        isInstalled = UserDefaults.standard.bool(forKey: installedCacheKey)
        if let cachedPythonPath = UserDefaults.standard.string(forKey: Self.selectedPythonPathKey),
           FileManager.default.fileExists(atPath: cachedPythonPath) {
            activePythonPath = cachedPythonPath
        }
        
        // Always verify in background — handles PearCleaner recovery (UserDefaults wiped
        // but Python packages still on disk) and stale cache scenarios
        checkInstallationStatus()
    }
    
    // MARK: - Installation Check
    
    func checkInstallationStatus() {
        Task {
            let candidates = await pythonCandidatePaths()
            detectedPythonPath = candidates.sorted { rankForInstall($0) < rankForInstall($1) }.first
            
            let installedPython = await findPythonWithTransparentBackground(in: candidates)
            setInstalledState(installedPython != nil, pythonPath: installedPython)
            
            if installedPython == nil, let detectedPythonPath {
                activePythonPath = detectedPythonPath
            }
        }
    }
    
    var recommendedManualInstallCommand: String {
        let preferredPath = activePythonPath ?? detectedPythonPath
        let python = (preferredPath.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }) ?? "python3"
        return "\(shellQuote(python)) -m pip install --user --upgrade transparent-background"
    }
    
    var hasDetectedPythonPath: Bool {
        guard let detectedPythonPath else { return false }
        return FileManager.default.fileExists(atPath: detectedPythonPath)
    }
    
    private func setInstalledState(_ installed: Bool, pythonPath: String?) {
        let previous = isInstalled
        
        isInstalled = installed
        UserDefaults.standard.set(installed, forKey: installedCacheKey)
        
        if let pythonPath {
            activePythonPath = pythonPath
            UserDefaults.standard.set(pythonPath, forKey: Self.selectedPythonPathKey)
        }
        
        if previous != installed {
            NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.aiBackgroundRemoval)
        }
    }
    
    private func findPythonWithTransparentBackground(in candidates: [String]) async -> String? {
        for pythonPath in candidates {
            if await isTransparentBackgroundInstalled(at: pythonPath) {
                return pythonPath
            }
        }
        return nil
    }
    
    private func isTransparentBackgroundInstalled(at pythonPath: String) async -> Bool {
        do {
            let result = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-c", "import transparent_background"]
            )
            return result.status == 0
        } catch {
            return false
        }
    }
    
    private func pythonCandidatePaths() async -> [String] {
        var candidates: [String] = []
        
        if let cachedPath = UserDefaults.standard.string(forKey: Self.selectedPythonPathKey) {
            candidates.append(cachedPath)
        }
        
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3"
        ])
        
        if let whichPath = await pythonPathFromWhich() {
            candidates.append(whichPath)
        }
        
        var seen: Set<String> = []
        var unique: [String] = []
        for path in candidates {
            guard !path.isEmpty else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if seen.insert(path).inserted {
                unique.append(path)
            }
        }
        
        return unique
    }
    
    private func pythonPathFromWhich() async -> String? {
        do {
            let result = try await runAIInstallProcess(executable: "/usr/bin/which", arguments: ["python3"])
            guard result.status == 0 else { return nil }
            guard let firstLine = result.output
                .split(separator: "\n")
                .map({ String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
                .first,
                firstLine.hasPrefix("/") else {
                return nil
            }
            return firstLine
        } catch {
            return nil
        }
    }
    
    private func selectPythonForInstall(from candidates: [String]) async -> String? {
        let sorted = candidates.sorted { rankForInstall($0) < rankForInstall($1) }
        for path in sorted {
            if await ensurePipAvailable(at: path) {
                return path
            }
        }
        return nil
    }
    
    private func rankForInstall(_ path: String) -> Int {
        if path.hasPrefix("/opt/homebrew/") { return 0 }
        if path.hasPrefix("/usr/local/") { return 1 }
        if path.hasPrefix("/Library/Frameworks/Python.framework/") { return 2 }
        if path == "/usr/bin/python3" { return 9 }
        return 3
    }
    
    private func hasPip(at pythonPath: String) async -> Bool {
        do {
            let result = try await runAIInstallProcess(executable: pythonPath, arguments: ["-m", "pip", "--version"])
            return result.status == 0
        } catch {
            return false
        }
    }
    
    private func ensurePipAvailable(at pythonPath: String) async -> Bool {
        if await hasPip(at: pythonPath) {
            return true
        }
        
        do {
            let bootstrap = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-m", "ensurepip", "--upgrade"]
            )
            if bootstrap.status == 0 {
                return await hasPip(at: pythonPath)
            }
        } catch {
            return false
        }
        
        return false
    }
    
    private func isXcodeCliInstalled() async -> Bool {
        do {
            let result = try await runAIInstallProcess(executable: "/usr/bin/xcode-select", arguments: ["-p"])
            return result.status == 0
        } catch {
            return false
        }
    }
    
    // MARK: - Installation
    
    /// Trigger Xcode Command Line Tools installation (shows macOS dialog)
    private func triggerXcodeCliInstall() async -> Bool {
        installProgress = "Python 3 not found. Requesting Command Line Tools..."
        
        do {
            let result = try await runAIInstallProcess(executable: "/usr/bin/xcode-select", arguments: ["--install"])
            if result.status != 0 {
                let output = result.output.lowercased()
                if !output.contains("already installed") {
                    return false
                }
            }
            
            installProgress = "Complete the Command Line Tools prompt, then retry install."
            
            // Poll for up to 3 minutes after prompting install.
            for _ in 0..<36 {
                if await isXcodeCliInstalled() {
                    return true
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
            return await isXcodeCliInstalled()
        } catch {
            return false
        }
    }
    
    func installTransparentBackground() async {
        isInstalling = true
        installProgress = "Checking existing installation..."
        installError = nil
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        var candidates = await pythonCandidatePaths()
        detectedPythonPath = candidates.sorted { rankForInstall($0) < rankForInstall($1) }.first
        
        if let installedPython = await findPythonWithTransparentBackground(in: candidates) {
            installProgress = "AI background removal is already installed."
            setInstalledState(true, pythonPath: installedPython)
            return
        }
        
        if candidates.isEmpty, !(await isXcodeCliInstalled()) {
            let requested = await triggerXcodeCliInstall()
            if requested {
                candidates = await pythonCandidatePaths()
                detectedPythonPath = candidates.sorted { rankForInstall($0) < rankForInstall($1) }.first
            }
        }
        
        guard !candidates.isEmpty else {
            installProgress = ""
            installError = "Python 3 is required. Install Command Line Tools or Python from python.org, then retry."
            return
        }
        
        guard let pythonPath = await selectPythonForInstall(from: candidates) else {
            installProgress = ""
            installError = "Python was found, but pip is unavailable. Install pip for Python 3 and retry."
            return
        }
        
        activePythonPath = pythonPath
        UserDefaults.standard.set(pythonPath, forKey: Self.selectedPythonPathKey)
        
        installProgress = "Installing transparent-background package..."
        
        let baseArgs = [
            "-m", "pip", "install",
            "--user",
            "--upgrade",
            "--disable-pip-version-check",
            "transparent-background"
        ]
        
        do {
            var result = try await runAIInstallProcess(executable: pythonPath, arguments: baseArgs)
            
            if result.status != 0 && result.output.lowercased().contains("externally-managed-environment") {
                installProgress = "Retrying with compatibility flags..."
                result = try await runAIInstallProcess(
                    executable: pythonPath,
                    arguments: baseArgs + ["--break-system-packages"]
                )
            }
            
            guard result.status == 0 else {
                installProgress = ""
                installError = formatInstallError(result.output)
                return
            }
            
            guard await isTransparentBackgroundInstalled(at: pythonPath) else {
                installProgress = ""
                installError = "Install finished, but verification failed. Click Re-check or run the manual command."
                return
            }
            
            installProgress = "Installation complete!"
            setInstalledState(true, pythonPath: pythonPath)
            
            // Keep legacy key for backward compatibility.
            UserDefaults.standard.set(true, forKey: "useLocalBackgroundRemoval")
            
            // Track extension activation
            AnalyticsService.shared.trackExtensionActivation(extensionId: "aiBackgroundRemoval")
        } catch {
            installProgress = ""
            installError = "Failed to start installation: \(error.localizedDescription)"
        }
    }
    
    private func formatInstallError(_ rawOutput: String) -> String {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        
        if normalized.contains("no module named pip") {
            return "pip is missing for this Python install. Install pip, then retry."
        }
        
        if normalized.contains("externally-managed-environment") {
            return "Python refused package changes in this environment. Use the manual command or a Homebrew/Python.org install."
        }
        
        if normalized.contains("permission denied") {
            return "Permission denied while installing Python packages. Check your user account permissions and retry."
        }
        
        if normalized.contains("network") || normalized.contains("timed out") {
            return "Network error while downloading dependencies. Check connection and retry."
        }
        
        if trimmed.isEmpty {
            return "Installation failed. Try again, then run the manual command if it still fails."
        }
        
        return "Installation failed: \(trimmed.prefix(220))"
    }
    
    // MARK: - Uninstall
    
    func uninstallTransparentBackground() async {
        isInstalling = true
        installProgress = "Removing package..."
        installError = nil
        
        defer {
            isInstalling = false
            checkInstallationStatus()
        }
        
        let candidates = await pythonCandidatePaths()
        var uninstallCandidates: [String] = []
        if let activePythonPath {
            uninstallCandidates.append(activePythonPath)
        }
        uninstallCandidates.append(contentsOf: candidates)
        
        var seen: Set<String> = []
        uninstallCandidates = uninstallCandidates.filter { seen.insert($0).inserted }
        
        var selectedPython: String?
        for path in uninstallCandidates {
            if await hasPip(at: path) {
                selectedPython = path
                break
            }
        }
        
        guard let pythonPath = selectedPython else {
            installError = "Python 3 not found. Cannot uninstall."
            return
        }
        
        do {
            let result = try await runAIInstallProcess(
                executable: pythonPath,
                arguments: ["-m", "pip", "uninstall", "-y", "transparent-background"]
            )
            
            let output = result.output.lowercased()
            if result.status == 0 || output.contains("not installed") {
                setInstalledState(false, pythonPath: nil)
                
                // Keep legacy key for backward compatibility.
                UserDefaults.standard.set(false, forKey: "useLocalBackgroundRemoval")
            } else {
                installError = "Failed to uninstall: \(result.output.prefix(200))"
            }
        } catch {
            installError = "Failed to uninstall: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Extension Removal Cleanup
    
    /// Clean up all AI Background Removal resources when extension is removed
    func cleanup() {
        Task {
            // Uninstall the Python package
            await uninstallTransparentBackground()
            
            // Clear cached state
            UserDefaults.standard.removeObject(forKey: installedCacheKey)
            UserDefaults.standard.removeObject(forKey: Self.selectedPythonPathKey)
            UserDefaults.standard.removeObject(forKey: "useLocalBackgroundRemoval")
            UserDefaults.standard.removeObject(forKey: "aiBackgroundRemovalTracked")
            
            // Reset state
            isInstalled = false
            activePythonPath = nil
            installProgress = ""
            installError = nil
            
            NotificationCenter.default.post(name: .extensionStateChanged, object: ExtensionType.aiBackgroundRemoval)
            
            print("[AIInstallManager] Cleanup complete")
        }
    }
    
    private func shellQuote(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "'\"$`\\"))) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
