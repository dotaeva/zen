//
//  Root.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI
import Observation

public protocol AnyRoot: AnyObject, CoordinatableData where Coordinator: RootCoordinatable {
    var root: Destination? { get set }
    var animation: Animation? { get set }
}

@Observable
public class Root<Coordinator: RootCoordinatable>: AnyRoot {
    public var root: Destination?
    public var parent: (any Coordinatable)?
    public var hasLayerNavigationCoordinator: Bool = false
    public var animation: Animation? = .default
    
    public var isSetup: Bool = false
    private var initialRoot: Coordinator.Destinations?
    
    public init(root: Coordinator.Destinations) {
        self.initialRoot = root
    }
    
    public func setup(for coordinator: Coordinator) {
        guard !isSetup else { return }
        if let rootDestination = initialRoot, root == nil {
            root = rootDestination.value(for: coordinator)
            self.initialRoot = nil
        }
        self.isSetup = true
    }
    
    public func setParent(_ parent: any Coordinatable) {
        self.parent = parent
    }
    
    func setAnimation(animation: Animation?) {
        self.animation = animation
    }
}

extension Root {
    func setRoot(root: Destination, animation: Animation?) {
        withAnimation(animation ?? self.animation) {
            self.root = root
        }
    }
}
