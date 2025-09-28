//
//  RootCoordinatable.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI
import Observation

public protocol RootCoordinatable: Coordinatable where ViewType == RootCoordinatableView {
    var root: Root<Self> { get }
    var anyRoot: any AnyRoot { get }
}

public extension RootCoordinatable {
    var _dataId: ObjectIdentifier {
        root.id
    }
    
    var anyRoot: any AnyRoot {
        root.setup(for: self)
        return root
    }
    
    func view() -> RootCoordinatableView {
        root.setup(for: self)
        return .init(coordinator: self)
    }
    
    var parent: (any Coordinatable)? {
        root.parent
    }
    
    var hasLayerNavigationCoordinatable: Bool {
        root.hasLayerNavigationCoordinator
    }
    
    func setHasLayerNavigationCoordinatable(_ value: Bool) {
        root.hasLayerNavigationCoordinator = value
    }
    
    func setParent(_ parent: any Coordinatable) {
        root.setParent(parent)
    }
}

public extension RootCoordinatable {
    @discardableResult
    func setRoot(_ destination: Destinations) -> Self {
        let dest = destination.value(for: self)
        
        root.root = dest
        
        return self
    }
    
    @discardableResult
    func setRoot<T>(
        _ destination: Destinations,
        value: @escaping (T) -> Void
    ) -> Self {
        let dest = destination.value(for: self)
        
        root.root = dest
        
        if dest.coordinatable != nil, let coordinatable = dest.coordinatable as? T {
            value(coordinatable)
        } else if let view = dest.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    func isRoot(_ destination: Destinations.Meta) -> Bool {
        return root.root?.meta as! Self.Destinations.Meta == destination
    }
}

public struct RootCoordinatableView: View {
    var coordinator: any RootCoordinatable
    
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
    
    @ViewBuilder
    func coordinatableView() -> some View {
        if let root = coordinator.anyRoot.root {
            wrappedView(root)
        } else {
            EmptyView()
        }
    }
    
    public var body: some View {
        coordinator.customize(
            AnyView(
                coordinatableView()
            )
        )
        .environmentCoordinatable(coordinator)
        .id(coordinator.anyRoot.id)
    }
}
