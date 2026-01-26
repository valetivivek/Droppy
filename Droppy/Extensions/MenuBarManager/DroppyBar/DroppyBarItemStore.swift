//
//  DroppyBarItemStore.swift
//  Droppy
//
//  Stores user-configured items to show in the Droppy Bar.
//  Users can manually select which menu bar icons appear.
//

import Foundation
import Combine

/// Represents a configured item for the Droppy Bar
struct DroppyBarItem: Codable, Identifiable, Hashable {
    /// Bundle identifier of the app (e.g., "com.apple.controlcenter")
    let bundleId: String
    
    /// Display name for the item
    let displayName: String
    
    /// Whether to show this item in the Droppy Bar
    var isEnabled: Bool = true
    
    var id: String { bundleId }
    
    init(bundleId: String, displayName: String, isEnabled: Bool = true) {
        self.bundleId = bundleId
        self.displayName = displayName
        self.isEnabled = isEnabled
    }
}

/// Stores and manages the list of items to show in Droppy Bar
@MainActor
final class DroppyBarItemStore: ObservableObject {
    
    /// List of configured items
    @Published var items: [DroppyBarItem] = [] {
        didSet {
            saveItems()
        }
    }
    
    /// UserDefaults key for persistence
    private let storageKey = "droppyBarConfiguredItems"
    
    // MARK: - Initialization
    
    init() {
        loadItems()
    }
    
    // MARK: - Public API
    
    /// Add an item to the Droppy Bar
    func addItem(bundleId: String, displayName: String) {
        // Don't add duplicates
        guard !items.contains(where: { $0.bundleId == bundleId }) else { return }
        
        let item = DroppyBarItem(bundleId: bundleId, displayName: displayName)
        items.append(item)
        print("[DroppyBarItemStore] Added item: \(displayName)")
    }
    
    /// Remove an item from the Droppy Bar
    func removeItem(bundleId: String) {
        items.removeAll { $0.bundleId == bundleId }
        print("[DroppyBarItemStore] Removed item: \(bundleId)")
    }
    
    /// Toggle an item's enabled state
    func toggleItem(bundleId: String) {
        if let index = items.firstIndex(where: { $0.bundleId == bundleId }) {
            items[index].isEnabled.toggle()
        }
    }
    
    /// Check if an item is configured (even if disabled)
    func isConfigured(bundleId: String) -> Bool {
        items.contains { $0.bundleId == bundleId }
    }
    
    /// Get only enabled items
    var enabledItems: [DroppyBarItem] {
        items.filter { $0.isEnabled }
    }
    
    /// Get bundle IDs of enabled items
    var enabledBundleIds: Set<String> {
        Set(enabledItems.map { $0.bundleId })
    }
    
    // MARK: - Persistence
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[DroppyBarItemStore] Failed to save: \(error)")
        }
    }
    
    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            items = try JSONDecoder().decode([DroppyBarItem].self, from: data)
            print("[DroppyBarItemStore] Loaded \(items.count) items")
        } catch {
            print("[DroppyBarItemStore] Failed to load: \(error)")
        }
    }
    
    /// Clear all configured items
    func clearAll() {
        items.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
