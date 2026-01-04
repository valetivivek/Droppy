import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: String? = "General"
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("useTransparentBackground") private var useTransparentBackground = false
    @AppStorage("enableNotchShelf") private var enableNotchShelf = true
    @AppStorage("enableFloatingBasket") private var enableFloatingBasket = true
    @AppStorage("hideNotchOnExternalDisplays") private var hideNotchOnExternalDisplays = false


    
    // Background Hover Effect State
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    
    var body: some View {
        ZStack {
            // Interactive background effect
            HexagonDotsEffect(
                mouseLocation: hoverLocation,
                isHovering: isHovering,
                coordinateSpaceName: "settingsView"
            )
            
            NavigationSplitView {
                List(selection: $selectedTab) {
                    Label("General", systemImage: "gear")
                        .tag("General")
                    Label("Display", systemImage: "display")
                        .tag("Display")

                    Label("About Droppy", systemImage: "info.circle")
                        .tag("About Droppy")
                        
                    Label("Beta", systemImage: "testtube.2")
                        .tag("Beta")
                }
                .navigationTitle("Settings")
                // Fix: Use compatible background modifer
                .background(Color.clear) 
            } detail: {
                Form {
                    if selectedTab == "General" {
                        generalSettings
                    } else if selectedTab == "Display" {
                        displaySettings

                    } else if selectedTab == "About Droppy" {
                        aboutSettings
                    } else if selectedTab == "Beta" {
                        betaSettings
                    }
                }
                .formStyle(.grouped)
                // Fix: Use compatible background modifier
                .background(Color.clear)
            }
        }
        .coordinateSpace(name: "settingsView")
        // Fix: Replace visionOS glassEffect with macOS material
        .background(.ultraThinMaterial)
        .onContinuousHover(coordinateSpace: .named("settingsView")) { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    isHovering = true
                }
            case .ended:
                withAnimation(.linear(duration: 0.2)) {
                    isHovering = false
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var generalSettings: some View {
        Section {
            Toggle(isOn: $showInMenuBar) {
                VStack(alignment: .leading) {
                    Text("Menu Bar Icon")
                    Text("Show Droppy in the menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle(isOn: Binding(
                get: { startAtLogin },
                set: { newValue in
                    startAtLogin = newValue
                    LaunchAtLoginManager.setLaunchAtLogin(enabled: newValue)
                }
            )) {
                VStack(alignment: .leading) {
                    Text("Startup")
                    Text("Start automatically at login")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $enableNotchShelf) {
                VStack(alignment: .leading) {
                    Text("Notch Shelf")
                    Text("Show the tray at the top of the screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: enableNotchShelf) { oldValue, newValue in
                if newValue {
                    NotchWindowController.shared.setupNotchWindow()
                } else {
                    NotchWindowController.shared.closeWindow()
                }
            }

            Toggle(isOn: $enableFloatingBasket) {
                VStack(alignment: .leading) {
                    Text("Floating Basket")
                    Text("Show the basket when jiggling files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: enableFloatingBasket) { oldValue, newValue in
                if !newValue {
                    FloatingBasketWindowController.shared.hideBasket()
                }
            }
        } header: {
            Text("General")
        } footer: {
            Text("Basic settings for the application.")
        }
    }
    
    private var displaySettings: some View {
        Section {
            Toggle(isOn: $useTransparentBackground) {
                VStack(alignment: .leading) {
                    Text("Transparent Background")
                    Text("Make the shelf and notch transparent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle(isOn: $hideNotchOnExternalDisplays) {
                VStack(alignment: .leading) {
                    Text("Hide Notch on External Displays")
                    Text("Don't show the visual notch on non-built-in displays")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Display")
        }
    }
    

    

    
    private var aboutSettings: some View {
        Section {
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.gradient)
                
                VStack(alignment: .leading) {
                    Text("Droppy")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Version \(UpdateChecker.shared.currentVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            LabeledContent("Developer", value: "Jordy Spruit")
            
            Button {
                UpdateChecker.shared.checkAndNotify()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Check for Updates")
                }
            }
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Beta
    @AppStorage("enableClipboardBeta") private var enableClipboardBeta = false
    @AppStorage("clipboardHistoryLimit") private var clipboardHistoryLimit = 50
    @State private var currentShortcut: SavedShortcut?
    
    // Custom Persistence for struct
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: "clipboardShortcut"),
           let decoded = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            currentShortcut = decoded
        } else {
            // Default: Shift + Cmd + Space (49)
            currentShortcut = SavedShortcut(keyCode: 49, modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue)
        }
    }
    
    private func saveShortcut(_ shortcut: SavedShortcut?) {
        if let s = shortcut, let encoded = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(encoded, forKey: "clipboardShortcut")
            // Update active monitor
            if enableClipboardBeta {
                 ClipboardWindowController.shared.startMonitoringShortcut()
            }
        }
    }
    
    private var betaSettings: some View {
        Section {
            Toggle(isOn: $enableClipboardBeta) {
                VStack(alignment: .leading) {
                    Text("Clipboard Manager")
                    Text("History with Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: enableClipboardBeta) { oldValue, newValue in
                if newValue {
                    // Check for Accessibility Permissions
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    let isTrusted = AXIsProcessTrustedWithOptions(options)
                    
                    if !isTrusted {
                        // User needs to approve. 
                        // The system prompt appears automatically due to options above.
                        // We can also show a helper alert if needed, but system prompt is standard.
                        print("Prompting for Accessibility permissions")
                    }
                    
                    ClipboardManager.shared.startMonitoring()
                    ClipboardWindowController.shared.startMonitoringShortcut()
                } else {
                    ClipboardManager.shared.stopMonitoring()
                    ClipboardWindowController.shared.stopMonitoringShortcut()
                    ClipboardWindowController.shared.close()
                }
            }
            
            if enableClipboardBeta {
                HStack {
                    Text("Global Shortcut")
                    Spacer()
                    KeyShortcutRecorder(shortcut: Binding(
                        get: { currentShortcut },
                        set: { newVal in
                            currentShortcut = newVal
                            saveShortcut(newVal)
                        }
                    ))
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("History Limit")
                        Text("Number of items to keep in history")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper(value: $clipboardHistoryLimit, in: 10...2000, step: 10) {
                        Text("\(clipboardHistoryLimit)")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        } header: {
            Text("Beta Features")
        } footer: {
            Text("Experimental features. Shortcuts may conflict with other apps. Requires Accessibility/Input Monitoring permissions for strict global shortcuts.")
        }
        .onAppear {
            loadShortcut()
        }
    }
}

// MARK: - Launch Handler

struct LaunchAtLoginManager {
    static func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.register()
                }
            } else {
                if #available(macOS 13.0, *) {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}
