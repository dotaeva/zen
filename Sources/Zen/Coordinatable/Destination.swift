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
        private let viewFactory: (() -> any View)?
        private var _cachedCoordinatable: (any Coordinatable)?
        private var _cachedView: (any View)?
        
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
                return view
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
        
        var view: (any View)? {
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
    
    var view: (any View)?
    var _tabItem: (any View)?
    var _coordinatable: CoordinatableCache?
    
    var pushType: DestinationType?
    var meta: any DestinationMeta
    var parent: any Coordinatable
    
    var onDismiss: (() -> Void)?
    
    public var coordinatable: (any Coordinatable)? {
        return _coordinatable?.coordinatable
    }
    
    public var tabItem: (any View)? {
        return _tabItem ?? _coordinatable?.view
    }
    
    public init<V: View>(
        _ value: V,
        meta: any DestinationMeta,
        parent: any Coordinatable,
    ) {
        self.view = value
        self.meta = meta
        self.parent = parent
    }
    
    public init(
        _ factory: @escaping () -> any Coordinatable,
        meta: any DestinationMeta,
        parent: any Coordinatable,
    ) {
        self._coordinatable = CoordinatableCache(factory)
        self.meta = meta
        self.parent = parent
    }
    
    public init<V: View>(
        _ factory: @escaping () -> (any Coordinatable, V),
        meta: any DestinationMeta,
        parent: any Coordinatable,
    ) {
        self._coordinatable = CoordinatableCache(factory)
        self.meta = meta
        self.parent = parent
    }
    
    public init<V: View, T: View>(
        _ factory: @escaping () -> (V, T),
        meta: any DestinationMeta,
        parent: any Coordinatable,
    ) {
        let (v, t) = factory()
        
        self.view = v
        self.meta = meta
        self.parent = parent
        self._tabItem = t
    }
    
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
