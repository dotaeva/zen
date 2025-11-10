//
//  TabItems.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI
import Observation

public protocol AnyTabItems: AnyObject, CoordinatableData where Coordinator: TabCoordinatable {
    var tabs: [Destination] { get set }
    var selectedTab: UUID? { get set }
    var tabBarVisibility: Visibility { get set }
}

@Observable
public class TabItems<Coordinator: TabCoordinatable>: AnyTabItems {
    public var parent: (any Coordinatable)?
    public var hasLayerNavigationCoordinator: Bool = false
    
    public var tabs: [Destination] = .init()
    public var selectedTab: UUID? = nil
    
    public var tabBarVisibility: Visibility = .automatic
    public var isSetup: Bool = false
    private var initialTabs: [Coordinator.Destinations] = .init()
    
    public init(tabs: [Coordinator.Destinations], visibility: Visibility = .automatic) {
        self.initialTabs = tabs
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
        selectedTab = tabs.first?.id
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
        guard index >= 0 && index < tabs.count else { return nil }
        let selectedDestination = tabs[index]
        selectedTab = selectedDestination.id
        return selectedDestination
    }
    
    func select(_ id: UUID) -> Destination? {
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
