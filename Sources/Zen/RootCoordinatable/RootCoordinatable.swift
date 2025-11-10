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

@MainActor
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
    
    func setRootTransitionAnimation(_ animation: Animation?) {
        root.setAnimation(animation: animation)
    }
}

@MainActor
public extension RootCoordinatable {
    @discardableResult
    func setRoot(_ destination: Destinations, animation: Animation? = nil) -> Self {
        let dest = destination.value(for: self)
        
        dest.coordinatable?.setParent(self)
        root.setRoot(root: dest, animation: animation)
        
        return self
    }
    
    @discardableResult
    func setRoot<T>(
        _ destination: Destinations,
        animation: Animation? = nil,
        value: @escaping (T) -> Void
    ) -> Self {
        let dest = destination.value(for: self)
        
        dest.coordinatable?.setParent(self)
        root.setRoot(root: dest, animation: animation)
        
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

public struct RootCoordinatableView: CoordinatableView {
    private let _coordinator: any RootCoordinatable
    
    public var coordinator: any Coordinatable {
        _coordinator
    }
    
    init(coordinator: any RootCoordinatable) {
        self._coordinator = coordinator
    }
    
    @ViewBuilder
    func coordinatableView() -> some View {
        if let root = _coordinator.anyRoot.root {
            wrappedView(root)
                .environmentCoordinatable(coordinator)
                .id(_coordinator.anyRoot.root?.id)
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
    }
}
