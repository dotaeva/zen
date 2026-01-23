//
//  FlowStack.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI
import Observation

@MainActor
public protocol AnyFlowStack: AnyObject, CoordinatableData where Coordinator: FlowCoordinatable {
    var root: Destination? { get set }
    var destinations: [Destination] { get set }
    var animation: Animation? { get set }
}

@MainActor
@Observable
public class FlowStack<Coordinator: FlowCoordinatable>: AnyFlowStack {
    public var root: Destination?
    public var parent: (any Coordinatable)?
    public var hasLayerNavigationCoordinator: Bool = false
    public var animation: Animation? = .default
    
    public var destinations: [Destination] = .init()
    
    public var isSetup: Bool = false
    private var initialRoot: Coordinator.Destinations?
    private var coordinator: Coordinator?
    
    public init(root: Coordinator.Destinations) {
        self.initialRoot = root
    }
    
    public func setup(for coordinator: Coordinator) {
        guard !isSetup else { return }
        self.coordinator = coordinator
        if let rootDestination = initialRoot, root == nil {
            var rootDest = rootDestination.value(for: coordinator)
            
            rootDest.coordinatable?.setHasLayerNavigationCoordinatable(true)
            
            root = rootDest
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

@MainActor
extension FlowStack {
    func push(destination: Destination) {
        destinations.append(destination)
    }
    
    func pop() {
        guard !destinations.isEmpty else {
            coordinator?.dismissCoordinator()
            return
        }
        destinations.removeLast()
    }
    
    func popToRoot() {
        destinations.removeAll()
    }
    
    func popToFirst(_ destination: Coordinator.Destinations.Meta) -> Destination? {
        if let root = root,
           let rootMeta = root.meta as? Coordinator.Destinations.Meta,
           rootMeta == destination {
            popToRoot()
            return root
        }
        
        guard let firstIndex = destinations.firstIndex(where: { dest in
            guard let destMeta = dest.meta as? Coordinator.Destinations.Meta else { return false }
            return destMeta == destination
        }) else {
            return nil
        }
        
        let targetDestination = destinations[firstIndex]
        
        let newCount = firstIndex + 1
        if destinations.count > newCount {
            destinations.removeSubrange(newCount...)
        }
        
        return targetDestination
    }
    
    func popToLast(_ destination: Coordinator.Destinations.Meta) -> Destination? {
        if let root = root,
           let rootMeta = root.meta as? Coordinator.Destinations.Meta,
           rootMeta == destination {
            popToRoot()
            return root
        }
        
        guard let lastIndex = destinations.lastIndex(where: { dest in
            guard let destMeta = dest.meta as? Coordinator.Destinations.Meta else { return false }
            return destMeta == destination
        }) else {
            return nil
        }
        
        let targetDestination = destinations[lastIndex]
        
        let newCount = lastIndex + 1
        if destinations.count > newCount {
            destinations.removeSubrange(newCount...)
        }
        
        return targetDestination
    }
    
    func setRoot(root: Destination, animation: Animation?) {
        withAnimation(animation ?? self.animation) {
            root.coordinatable?.setHasLayerNavigationCoordinatable(true)
            self.root = root
        }
    }
}
