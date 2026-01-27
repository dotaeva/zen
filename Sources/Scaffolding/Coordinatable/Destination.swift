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
    case root
    case push
    case sheet
    case fullScreenCover
    
    var isModal: Bool {
        switch self {
        case .sheet, .fullScreenCover:
            return true
        default: return false
        }
    }
    
    static func from(presentationType: PresentationType) -> DestinationType {
        return switch presentationType {
        case .push:
                .push
        case .sheet:
                .sheet
        case .fullScreenCover:
                .fullScreenCover
        }
    }
}

@MainActor
public enum PresentationType {
    case push
    case sheet
    case fullScreenCover
}

// MARK: - Environment Key

// MARK: - Environment Key

private struct DestinationEnvironmentKey: @MainActor EnvironmentKey {
    @MainActor static let defaultValue: Destination = .dummy
}

public extension EnvironmentValues {
    @MainActor
    var destination: Destination {
        get { self[DestinationEnvironmentKey.self] }
        set { self[DestinationEnvironmentKey.self] = newValue }
    }
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
        @available(macOS 15, *)
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
    
    private var _view: AnyView?
    private var _tabItem: AnyView?
    var _coordinatable: CoordinatableCache?
    
    @available(iOS 18, *)
    @available(macOS 15, *)
    var tabRole: TabRole? {
        get { _tabRole as? TabRole }
        set { _tabRole = newValue }
    }
    
    private var _tabRole: Any?
    
    var pushType: PresentationType?
    public var routeType: DestinationType = .root
    public var presentationType: DestinationType {
        switch pushType {
        case .push:
                .push
        case .sheet:
                .sheet
        case .fullScreenCover:
                .fullScreenCover
        case nil:
                .root
        }
    }
    
    public let meta: any DestinationMeta
    var parent: any Coordinatable
    
    var onDismiss: (() -> Void)?
    
    var coordinatable: (any Coordinatable)? {
        return _coordinatable?.coordinatable
    }
    
    // MARK: - Environment-Injected Accessors
    
    /// Returns the view with Destination injected into environment
    var view: AnyView? {
        guard let v = _view else { return nil }
        return AnyView(v.environment(\.destination, self))
    }
    
    /// Returns the tab item view with Destination injected into environment
    var tabItem: AnyView? {
        guard let item = _tabItem ?? _coordinatable?.view else { return nil }
        return AnyView(item.environment(\.destination, self))
    }
    
    // MARK: - Basic Initializers
    
    /// Initializer for `some View`
    public init<V: View>(
        _ value: V,
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        self._view = AnyView(value)
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
        
        self._view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self._tabItem = AnyView(t)
    }
    
    // MARK: - TabRole Initializers
    
    /// Initializer for `(some View, TabRole)`
    @available(iOS 18, *)
    @available(macOS 15, *)
    public init<V: View>(
        _ factory: @escaping () -> (V, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let (v, role) = factory()
        
        self._view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self._tabRole = role
    }
    
    /// Initializer for `(any Coordinatable, TabRole)`
    @available(iOS 18, *)
    @available(macOS 15, *)
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
    @available(macOS 15, *)
    public init<V: View, T: View>(
        _ factory: @escaping () -> (V, T, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let (v, t, role) = factory()
        
        self._view = AnyView(v)
        self.meta = meta
        self.parent = parent
        self._tabItem = AnyView(t)
        self._tabRole = role
    }
    
    /// Initializer for `(any Coordinatable, some View, TabRole)` - coordinatable + tab item + role
    @available(iOS 18, *)
    @available(macOS 15, *)
    public init<V: View>(
        _ factory: @escaping () -> (any Coordinatable, V, TabRole),
        meta: any DestinationMeta,
        parent: any Coordinatable
    ) {
        let result = factory()
        
        self._coordinatable = CoordinatableCache(factory)
        self.meta = meta
        self.parent = parent
        self._tabRole = result.2
    }
    
    // MARK: - Mutating Methods
    
    mutating func setOnDismiss(_ value: @escaping () -> Void) {
        onDismiss = value
    }
    
    mutating func setPushType(_ value: PresentationType) {
        pushType = value
    }
    
    mutating func setRouteType(_ value: DestinationType) {
        routeType = value
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
