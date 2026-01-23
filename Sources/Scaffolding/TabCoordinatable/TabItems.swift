//
//  TabItems.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI
import Observation

@MainActor
public protocol AnyTabItems: AnyObject, CoordinatableData where Coordinator: TabCoordinatable {
    var tabs: [Destination] { get set }
    var selectedTab: UUID? { get set }
    var tabBarVisibility: Visibility { get set }
}

@MainActor
@Observable
public class TabItems<Coordinator: TabCoordinatable>: AnyTabItems {
    public var parent: (any Coordinatable)?
    public var hasLayerNavigationCoordinator: Bool = false
    
    public var tabs: [Destination] = .init()
    public var selectedTab: UUID? = nil
    
    public var tabBarVisibility: Visibility = .automatic
    public var isSetup: Bool = false
    private var initialTabs: [Coordinator.Destinations] = .init()
    
    private var pendingSelectionIndex: Int? = nil
    private var pendingSelectionId: UUID? = nil
    private var pendingSelectionFirstMeta: Coordinator.Destinations.Meta? = nil
    private var pendingSelectionLastMeta: Coordinator.Destinations.Meta? = nil
    
    public init(
        tabs: [Coordinator.Destinations],
        selectedIndex: Int? = nil,
        visibility: Visibility = .automatic
    ) {
        self.initialTabs = tabs
        self.pendingSelectionIndex = selectedIndex
        self.tabBarVisibility = visibility
    }
    
    public func setup(for coordinator: Coordinator) {
        guard !isSetup else { return }
        self.tabs = initialTabs.map {
            let t = $0.value(for: coordinator)
            t.coordinatable?.setHasLayerNavigationCoordinatable(coordinator.hasLayerNavigationCoordinatable)
            t.coordinatable?.setParent(coordinator)
            return t
        }
        
        if let pendingId = pendingSelectionId,
           let foundTab = tabs.first(where: { $0.id == pendingId }) {
            selectedTab = foundTab.id
        } else if let pendingMeta = pendingSelectionFirstMeta,
                  let foundTab = tabs.first(where: { destination in
                      guard let destinationMeta = destination.meta as? Coordinator.Destinations.Meta else { return false }
                      return destinationMeta == pendingMeta
                  }) {
            selectedTab = foundTab.id
        } else if let pendingMeta = pendingSelectionLastMeta,
                  let foundTab = tabs.last(where: { destination in
                      guard let destinationMeta = destination.meta as? Coordinator.Destinations.Meta else { return false }
                      return destinationMeta == pendingMeta
                  }) {
            selectedTab = foundTab.id
        } else if let pendingIndex = pendingSelectionIndex,
                  pendingIndex >= 0 && pendingIndex < tabs.count {
            selectedTab = tabs[pendingIndex].id
        } else {
            selectedTab = tabs.first?.id
        }
        
        pendingSelectionIndex = nil
        pendingSelectionId = nil
        pendingSelectionFirstMeta = nil
        pendingSelectionLastMeta = nil
        
        self.isSetup = true
    }
    
    public func setParent(_ parent: any Coordinatable) {
        self.parent = parent
    }
    
    func setTabBarVisibility(_ value: Visibility) {
        self.tabBarVisibility = value
    }
}

extension TabItems {
    func select(first tab: Coordinator.Destinations.Meta) -> Destination? {
        guard isSetup else {
            pendingSelectionFirstMeta = tab
            pendingSelectionLastMeta = nil
            pendingSelectionIndex = nil
            pendingSelectionId = nil
            return nil
        }
        
        if let foundTab = tabs.first(where: { destination in
            guard let destinationMeta = destination.meta as? Coordinator.Destinations.Meta else { return false }
            return destinationMeta == tab
        }) {
            selectedTab = foundTab.id
            return foundTab
        }
        return nil
    }
    
    func select(last tab: Coordinator.Destinations.Meta) -> Destination? {
        guard isSetup else {
            pendingSelectionLastMeta = tab
            pendingSelectionFirstMeta = nil
            pendingSelectionIndex = nil
            pendingSelectionId = nil
            return nil
        }
        
        if let foundTab = tabs.last(where: { destination in
            guard let destinationMeta = destination.meta as? Coordinator.Destinations.Meta else { return false }
            return destinationMeta == tab
        }) {
            selectedTab = foundTab.id
            return foundTab
        }
        return nil
    }
    
    func select(_ index: Int) -> Destination? {
        guard isSetup else {
            if index >= 0 && index < initialTabs.count {
                pendingSelectionIndex = index
                pendingSelectionFirstMeta = nil
                pendingSelectionLastMeta = nil
                pendingSelectionId = nil
            }
            return nil
        }
        
        guard index >= 0 && index < tabs.count else { return nil }
        let selectedDestination = tabs[index]
        selectedTab = selectedDestination.id
        return selectedDestination
    }
    
    func select(_ id: UUID) -> Destination? {
        guard isSetup else {
            pendingSelectionId = id
            pendingSelectionIndex = nil
            pendingSelectionFirstMeta = nil
            pendingSelectionLastMeta = nil
            return nil
        }
        
        if let foundTab = tabs.first(where: { $0.id == id }) {
            selectedTab = foundTab.id
            return foundTab
        }
        return nil
    }
    
    func setTabs(_ tabs: [Destination]) {
        self.tabs = tabs
        
        if let selectedTab = selectedTab,
           !tabs.contains(where: { $0.id == selectedTab }) {
            self.selectedTab = tabs.first?.id
        }
    }
    
    func appendTab(_ tab: Destination) -> Destination {
        tabs.append(tab)
        
        if selectedTab == nil {
            selectedTab = tab.id
        }
        
        return tab
    }
    
    func insertTab(_ tab: Destination, at index: Int) -> Destination {
        let clampedIndex = max(0, min(index, tabs.count))
        tabs.insert(tab, at: clampedIndex)
        
        if selectedTab == nil {
            selectedTab = tab.id
        }
        
        return tab
    }
    
    func removeFirstTab(_ meta: Coordinator.Destinations.Meta) {
        guard let index = tabs.firstIndex(where: { destination in
            guard let destinationMeta = destination.meta as? Coordinator.Destinations.Meta else { return false }
            return destinationMeta == meta
        }) else { return }
        
        let removedTab = tabs.remove(at: index)
        
        if selectedTab == removedTab.id {
            if !tabs.isEmpty {
                let newIndex = min(index, tabs.count - 1)
                selectedTab = tabs[newIndex].id
            } else {
                selectedTab = nil
            }
        }
    }
    
    func removeLastTab(_ meta: Coordinator.Destinations.Meta) {
        guard let index = tabs.lastIndex(where: { destination in
            guard let destinationMeta = destination.meta as? Coordinator.Destinations.Meta else { return false }
            return destinationMeta == meta
        }) else { return }
        
        let removedTab = tabs.remove(at: index)
        
        if selectedTab == removedTab.id {
            if !tabs.isEmpty {
                let newIndex = min(index, tabs.count - 1)
                selectedTab = tabs[newIndex].id
            } else {
                selectedTab = nil
            }
        }
    }
}
