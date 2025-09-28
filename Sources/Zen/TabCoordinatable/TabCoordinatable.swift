//
//  TabCoordinatable.swift
//  Zen
//
//  Created by Alexandr Valíček on 24.09.2025.
//

import SwiftUI
import Observation

public protocol TabCoordinatable: Coordinatable where ViewType == TabCoordinatableView {
    var tabItems: TabItems<Self> { get }
    var anyTabItems: any AnyTabItems { get }
}

public extension TabCoordinatable {
    var _dataId: ObjectIdentifier {
        tabItems.id
    }
    
    var anyTabItems: any AnyTabItems {
        tabItems.setup(for: self)
        return tabItems
    }
    
    func view() -> TabCoordinatableView {
        tabItems.setup(for: self)
        return .init(coordinator: self)
    }
    
    var parent: (any Coordinatable)? {
        tabItems.parent
    }
    
    var hasLayerNavigationCoordinatable: Bool {
        tabItems.hasLayerNavigationCoordinator
    }
    
    func setHasLayerNavigationCoordinatable(_ value: Bool) {
        tabItems.hasLayerNavigationCoordinator = value
    }
    
    func setParent(_ parent: any Coordinatable) {
        tabItems.setParent(parent)
    }
}

extension TabCoordinatable {
    var selectedTabBinding: Binding<UUID?> {
        Binding(
            get: { self.tabItems.selectedTab },
            set: { self.tabItems.selectedTab = $0 }
        )
    }
}

public extension TabCoordinatable {
    @discardableResult
    func selectFirstTab(_ tab: Destinations.Meta) -> Self {
        let _ = tabItems.select(first: tab)
        return self
    }
    
    @discardableResult
    func selectFirstTab<T>(
        _ tab: Destinations.Meta,
        value: @escaping (T) -> Void
    ) -> Self {
        let tab = tabItems.select(first: tab)
        
        guard let tab else { return self }
        
        if tab.coordinatable != nil, let coordinatable = tab.coordinatable as? T {
            value(coordinatable)
        } else if let view = tab.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func selectLastTab(_ tab: Destinations.Meta) -> Self {
        let _ = tabItems.select(last: tab)
        return self
    }
    
    @discardableResult
    func selectLastTab<T>(
        _ tab: Destinations.Meta,
        value: @escaping (T) -> Void
    ) -> Self {
        let tab = tabItems.select(last: tab)
        
        guard let tab else { return self }
        
        if tab.coordinatable != nil, let coordinatable = tab.coordinatable as? T {
            value(coordinatable)
        } else if let view = tab.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func select(index: Int) -> Self {
        let _ = tabItems.select(index)
        return self
    }
    
    @discardableResult
    func select<T>(
        index: Int,
        value: @escaping (T) -> Void
    ) -> Self {
        let tab = tabItems.select(index)
        
        guard let tab else { return self }
        
        if tab.coordinatable != nil, let coordinatable = tab.coordinatable as? T {
            value(coordinatable)
        } else if let view = tab.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func setTabs(_ tabs: [Destinations]) -> Self {
        let tabs = tabs.map {
            let t = $0.value(for: self)
            t.coordinatable?.setHasLayerNavigationCoordinatable(self.hasLayerNavigationCoordinatable)
            return t
        }
        
        tabItems.setTabs(tabs)
        
        return self
    }
    
    @discardableResult
    func appendTab(_ tab: Destinations) -> Self {
        let tab = tab.value(for: self)
        tab.coordinatable?.setHasLayerNavigationCoordinatable(self.hasLayerNavigationCoordinatable)
        
        let _ = tabItems.appendTab(tab)
        
        return self
    }
    
    @discardableResult
    func appendTab<T>(
        _ tab: Destinations,
        value: @escaping (T) -> Void
    ) -> Self {
        let t = tab.value(for: self)
        t.coordinatable?.setHasLayerNavigationCoordinatable(self.hasLayerNavigationCoordinatable)
        
        let tab = tabItems.appendTab(t)
        
        if tab.coordinatable != nil, let coordinatable = tab.coordinatable as? T {
            value(coordinatable)
        } else if let view = tab.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func insertTab(_ tab: Destinations, at index: Int) -> Self {
        let tab = tab.value(for: self)
        tab.coordinatable?.setHasLayerNavigationCoordinatable(self.hasLayerNavigationCoordinatable)
        
        let _ = tabItems.insertTab(tab, at: index)
        
        return self
    }
    
    @discardableResult
    func insertTab<T>(
        _ tab: Destinations,
        at index: Int,
        value: @escaping (T) -> Void
    ) -> Self {
        let t = tab.value(for: self)
        t.coordinatable?.setHasLayerNavigationCoordinatable(self.hasLayerNavigationCoordinatable)
        
        let tab = tabItems.insertTab(t, at: index)
        
        if tab.coordinatable != nil, let coordinatable = tab.coordinatable as? T {
            value(coordinatable)
        } else if let view = tab.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func removeFirstTab(_ meta: Destinations.Meta) -> Self {
        tabItems.removeFirstTab(meta)
        return self
    }
    
    @discardableResult
    func removeLastTab(_ meta: Destinations.Meta) -> Self {
        tabItems.removeLastTab(meta)
        return self
    }
    
    func isInTabItems(_ meta: Destinations.Meta) -> Bool {
        tabItems.tabs.contains(where: { $0.meta as! Self.Destinations.Meta == meta })
    }
}

public struct TabCoordinatableView: View {
    var coordinator: any TabCoordinatable
    
    @ViewBuilder
    func wrappedView(_ destination: Destination) -> some View {
        let content = Group {
            if let view = destination.view {
                view.environmentCoordinatable(destination.parent)
            } else if let c = destination.coordinatable {
                AnyView(c.view())
            } else {
                EmptyView()
            }
        }
        
        if destination.parent._dataId != coordinator._dataId {
            destination.parent.customize(AnyView(content))
        } else {
            content
        }
    }
    
    private func flowCoordinatableView() -> some View {
        TabView(selection: coordinator.selectedTabBinding) {
            ForEach(coordinator.anyTabItems.tabs) { tab in
                wrappedView(tab)
                    .environmentCoordinatable(coordinator)
                    .tabItem {
                        if let tabItem = tab.tabItem {
                            AnyView(tabItem)
                        }
                    }
                    .tag(tab.id)
            }
        }
    }
    
    public var body: some View {
        coordinator.customize(
            AnyView(
                flowCoordinatableView()
            )
        )
        .environmentCoordinatable(coordinator)
        .id(coordinator.anyTabItems.id)
    }
}
