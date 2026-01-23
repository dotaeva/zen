//
//  Destination.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 22.09.2025.
//

import SwiftUI

@MainActor
public protocol DestinationMeta: Equatable { }

@MainActor
public enum DestinationType {
    case push
    case sheet
    case fullScreenCover
}

@MainActor
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
        
        @available(iOS 18, *)
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
    
    @available(iOS 18, *)
    var tabRole: TabRole? {
        get { _tabRole as? TabRole }
        set { _tabRole = newValue }
    }
    
    private var _tabRole: Any?
    
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
    @available(iOS 18, *)
    public init<V: View>(
        _ factory: @escaping () -> (V, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let (v, role) = factory()
        
        self.view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self._tabRole = role
    }
    
    /// Initializer for `(any Coordinatable, TabRole)`
    @available(iOS 18, *)
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
        self._tabRole = role
    }
    
    /// Initializer for `(some View, some View, TabRole)` - view + tab item + role
    @available(iOS 18, *)
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
        self._tabRole = role
    }
    
    /// Initializer for `(any Coordinatable, some View, TabRole)` - coordinatable + tab item + role
    @available(iOS 18, *)
    public init<V: View>(
        _ factory: @escaping () -> (any Coordinatable, V, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let result = factory()
        
        self._coordinatable = CoordinatableCache(factory) // ✅ Pass factory directly
        self.meta = meta
        self.parent = parent
        self._tabRole = result.2
    }
    
    // MARK: - Mutating Methods
    
    mutating func setOnDismiss(_ value: @escaping () -> Void) {
        onDismiss = value
    }
    
    mutating func setPushType(_ value: DestinationType) {
        pushType = value
    }
}

@MainActor
extension Destination: @MainActor Equatable, @MainActor Hashable {
    public static func ==(lhs: Destination, rhs: Destination) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
