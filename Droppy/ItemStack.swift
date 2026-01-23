//
//  ItemStack.swift
//  Droppy
//
//  Created by Jordy Spruit on 22/01/2026.
//

import SwiftUI

// MARK: - Item Stack Model

/// Represents a stack of items dropped together
/// Stacks group files that were dropped in a single operation, displaying them
/// as a visual pile that can be expanded to show individual items.
struct ItemStack: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    var items: [DroppedItem]
    var isExpanded: Bool = false
    
    /// If true, always renders as a stack even with only 1 item (for tracked folders)
    var forceStackAppearance: Bool = false
    
    /// The "cover" item shown when collapsed (first item in the stack)
    var coverItem: DroppedItem? { items.first }
    
    /// Stack count for badge display
    var count: Int { items.count }
    
    /// Whether this is a single-item stack (renders as individual item, not pile)
    /// Tracked folder stacks always appear as stacks (forceStackAppearance)
    var isSingleItem: Bool { items.count == 1 && !forceStackAppearance }
    
    /// Whether the stack is empty
    var isEmpty: Bool { items.isEmpty }
    
    /// All item IDs in this stack (for selection operations)
    var itemIds: Set<UUID> { Set(items.map { $0.id }) }
    
    // MARK: - Initialization
    
    init(items: [DroppedItem]) {
        self.id = UUID()
        self.createdAt = Date()
        self.items = items
    }
    
    /// Creates a stack with a single item
    init(item: DroppedItem) {
        self.init(items: [item])
    }
    
    // MARK: - Hashable & Equatable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ItemStack, rhs: ItemStack) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Mutations
    
    /// Removes an item from the stack by ID
    mutating func removeItem(withId itemId: UUID) {
        items.removeAll { $0.id == itemId }
    }
    
    /// Removes an item from the stack
    mutating func removeItem(_ item: DroppedItem) {
        removeItem(withId: item.id)
    }
    
    /// Adds an item to the stack
    mutating func addItem(_ item: DroppedItem) {
        items.append(item)
    }
    
    /// Cleans up all temporary files in the stack
    func cleanupTemporaryFiles() {
        for item in items {
            item.cleanupIfTemporary()
        }
    }
}

// MARK: - Stack Animations

extension ItemStack {
    /// Animation for stack expansion (items fanning out)
    /// Faster for large stacks to prevent lag
    static let expandAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    
    /// Animation for stack collapse
    static let collapseAnimation: Animation = .spring(response: 0.25, dampingFraction: 0.95)
    
    /// Animation for hover peek (quick response)
    static let peekAnimation: Animation = .spring(response: 0.25, dampingFraction: 0.7)
    
    /// Stagger delay between items during expansion
    /// CAPPED at 10 items to prevent lag with large stacks (40+ items)
    static func staggerDelay(for index: Int) -> Double {
        // Cap at 10 items (350ms max total stagger)
        let cappedIndex = min(index, 10)
        return Double(cappedIndex) * 0.025 // 25ms between each (was 35ms)
    }
}

// MARK: - Stack Transition

extension AnyTransition {
    /// Transition for stack appearing/disappearing (symmetric bounce in/out)
    static var stackDrop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.7)
                .combined(with: .opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.85)),
            removal: .scale(scale: 0.7)
                .combined(with: .opacity)
                .animation(.spring(response: 0.2, dampingFraction: 0.9))
        )
    }
    
    /// Transition for items expanding from stack
    /// Optimized: no offset transitions to prevent layout jump during expansion
    static func stackExpand(index: Int) -> AnyTransition {
        // For large stacks (>10 items), use simple fade - no stagger
        let isLargeStack = index > 10
        
        if isLargeStack {
            // Simple fade for items beyond first 10 - no stagger, minimal animation
            return .opacity.animation(.easeOut(duration: 0.15))
        }
        
        // Use only scale + opacity (NO offset) to prevent layout jump
        return .asymmetric(
            insertion: .scale(scale: 0.85)
                .combined(with: .opacity)
                .animation(.easeOut(duration: 0.2).delay(ItemStack.staggerDelay(for: index))),
            removal: .scale(scale: 0.85)
                .combined(with: .opacity)
                .animation(.easeOut(duration: 0.15))
        )
    }
}
