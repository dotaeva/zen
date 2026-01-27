//
//  TabCoordinatable.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 24.09.2025.
//

import SwiftUI
import Observation

@MainActor
public protocol TabCoordinatable: Coordinatable where ViewType == TabCoordinatableView {
    var tabItems: TabItems<Self> { get }
    var anyTabItems: any AnyTabItems { get }
    var presentedAs: PresentationType? { get set }
}

@MainActor
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
    
    func setTabBarVisibility(_ value: Visibility) {
        tabItems.setTabBarVisibility(value)
    }
}

@MainActor
extension TabCoordinatable {
    var selectedTabBinding: Binding<UUID?> {
        Binding(
            get: { self.tabItems.selectedTab },
            set: { self.tabItems.selectedTab = $0 }
        )
    }
}

@MainActor
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
    func select(id: UUID) -> Self {
        let _ = tabItems.select(id)
        return self
    }
    
    @discardableResult
    func select<T>(
        id: UUID,
        value: @escaping (T) -> Void
    ) -> Self {
        let tab = tabItems.select(id)
        
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
            t.coordinatable?.setParent(self)
            return t
        }
        
        tabItems.setTabs(tabs)
        
        return self
    }
    
    @discardableResult
    func appendTab(_ tab: Destinations) -> Self {
        let tab = tab.value(for: self)
        tab.coordinatable?.setHasLayerNavigationCoordinatable(self.hasLayerNavigationCoordinatable)
        tab.coordinatable?.setParent(self)
        
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
        t.coordinatable?.setParent(self)
        
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
        tab.coordinatable?.setParent(self)
        
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
        t.coordinatable?.setParent(self)
        
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

public extension TabCoordinatable {
    func setPresentedAs(_ type: PresentationType) {
        anyTabItems.presentedAs = type
        for i in anyTabItems.tabs.indices {
            if anyTabItems.tabs[i].pushType == nil {
                anyTabItems.tabs[i].setPushType(type)
            }
        }
    }
}

public struct TabCoordinatableView: CoordinatableView {
    private let _coordinator: any TabCoordinatable
    
    public var coordinator: any Coordinatable {
        _coordinator
    }
    
    init(coordinator: any TabCoordinatable) {
        self._coordinator = coordinator
    }
    
    @ViewBuilder
    private func flowCoordinatableView() -> some View {
        if #available(iOS 18, macOS 15, *) {
            flowCoordinatableViewiOS18()
        } else {
            flowCoordinatableViewiOS17()
        }
    }

    @available(iOS 18, macOS 15, *)
    private func flowCoordinatableViewiOS18() -> some View {
        TabView(selection: _coordinator.selectedTabBinding) {
            ForEach(_coordinator.anyTabItems.tabs) { tab in
                Tab(value: tab.id, role: tab.tabRole) {
                    wrappedView(tab)
                        .environmentCoordinatable(_coordinator)
#if os(iOS)
                        .toolbar(_coordinator.anyTabItems.tabBarVisibility, for: .tabBar)
#endif
                } label: {
                    if let tabItem = tab.tabItem {
                        AnyView(tabItem)
                    }
                }
            }
        }
    }
    
    private func flowCoordinatableViewiOS17() -> some View {
        TabView(selection: _coordinator.selectedTabBinding) {
            ForEach(_coordinator.anyTabItems.tabs) { tab in
                wrappedView(tab)
                    .environmentCoordinatable(_coordinator)
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
        _coordinator.customize(
            AnyView(
                flowCoordinatableView()
            )
        )
        .environmentCoordinatable(coordinator)
        .id(_coordinator.anyTabItems.id)
    }
}
