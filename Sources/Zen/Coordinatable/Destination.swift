//
//  Destination.swift
//  Zen
//
//  Created by Alexandr Valíček on 22.09.2025.
//

import SwiftUI

public protocol DestinationMeta: Equatable { }

public enum DestinationType {
    case push
    case sheet
    case fullScreenCover
}

public struct Destination: Identifiable {
    class CoordinatableCache {
        private let coordinatableFactory: () -> any Coordinatable
        private let viewFactory: (() -> AnyView)?
        private var _cachedCoordinatable: (any Coordinatable)?
        private var _cachedView: AnyView?
        
        init(_ factory: @escaping () -> any Coordinatable) {
            self.coordinatableFactory = factory
            self.viewFactory = nil
        }
        
        init<V: View>(_ factory: @escaping () -> (any Coordinatable, V)) {
            self.coordinatableFactory = {
                let (coordinatable, _) = factory()
                return coordinatable
            }
            self.viewFactory = {
                let (_, view) = factory()
                return AnyView(view)
            }
        }
        
        init<V: View>(_ factory: @escaping () -> (any Coordinatable, V, TabRole)) {
            self.coordinatableFactory = {
                let (coordinatable, _, _) = factory()
                return coordinatable
            }
            self.viewFactory = {
                let (_, view, _) = factory()
                return AnyView(view)
            }
        }
        
        var coordinatable: any Coordinatable {
            if let cached = _cachedCoordinatable {
                return cached
            }
            let instance = coordinatableFactory()
            _cachedCoordinatable = instance
            return instance
        }
        
        var view: AnyView? {
            guard let viewFactory = viewFactory else { return nil }
            
            if let cached = _cachedView {
                return cached
            }
            let instance = viewFactory()
            _cachedView = instance
            return instance
        }
    }
    
    public var id: UUID = .init()
    
    var view: AnyView?
    var _tabItem: AnyView?
    var _coordinatable: CoordinatableCache?
    
    var tabRole: TabRole?
    var pushType: DestinationType?
    public let meta: any DestinationMeta
    var parent: any Coordinatable
    
    var onDismiss: (() -> Void)?
    
    public var coordinatable: (any Coordinatable)? {
        return _coordinatable?.coordinatable
    }
    
    public var tabItem: AnyView? {
        return _tabItem ?? _coordinatable?.view
    }
    
    // MARK: - Basic Initializers
    
    /// Initializer for `some View`
    public init<V: View>(
        _ value: V,
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        self.view = AnyView(value)
        self.meta = meta
        self.parent = parent
    }
    
    /// Initializer for `any Coordinatable`
    public init(
        _ factory: @escaping () -> any Coordinatable,
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        self._coordinatable = CoordinatableCache(factory)
        self.meta = meta
        self.parent = parent
    }
    
    /// Initializer for `(any Coordinatable, some View)`
    public init<V: View>(
        _ factory: @escaping () -> (any Coordinatable, V),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        self._coordinatable = CoordinatableCache(factory)
        self.meta = meta
        self.parent = parent
    }
    
    /// Initializer for `(some View, some View)` - view + tab item
    public init<V: View, T: View>(
        _ factory: @escaping () -> (V, T),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let (v, t) = factory()
        
        self.view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self._tabItem = AnyView(t)
    }
    
    // MARK: - TabRole Initializers
    
    /// Initializer for `(some View, TabRole)`
    public init<V: View>(
        _ factory: @escaping () -> (V, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let (v, role) = factory()
        
        self.view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self.tabRole = role
    }
    
    /// Initializer for `(any Coordinatable, TabRole)`
    public init(
        _ factory: @escaping () -> (any Coordinatable, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let result = factory()
        let role = result.1
        
        self._coordinatable = CoordinatableCache({ result.0 })
        self.meta = meta
        self.parent = parent
        self.tabRole = role
    }
    
    /// Initializer for `(some View, some View, TabRole)` - view + tab item + role
    public init<V: View, T: View>(
        _ factory: @escaping () -> (V, T, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let (v, t, role) = factory()
        
        self.view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self._tabItem = AnyView(t)
        self.tabRole = role
    }
    
    /// Initializer for `(any Coordinatable, some View, TabRole)` - coordinatable + tab item + role
    public init<V: View>(
        _ factory: @escaping () -> (any Coordinatable, V, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let result = factory()
        let role = result.2
        
        self._coordinatable = CoordinatableCache({ (result.0, result.1, result.2) })
        self.meta = meta
        self.parent = parent
        self.tabRole = role
    }
    
    // MARK: - Mutating Methods
    
    mutating func setOnDismiss(_ value: @escaping () -> Void) {
        onDismiss = value
    }
    
    mutating func setPushType(_ value: DestinationType) {
        pushType = value
    }
}

extension Destination: Equatable, Hashable {
    public static func ==(lhs: Destination, rhs: Destination) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
