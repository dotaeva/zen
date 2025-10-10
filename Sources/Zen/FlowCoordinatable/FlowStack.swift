//
//  FlowStack.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI
import Observation

public protocol AnyFlowStack: AnyObject, CoordinatableData where Coordinator: FlowCoordinatable {
    var root: Destination? { get set }
    var destinations: [Destination] { get set }
    var animation: Animation? { get set }
}

@Observable
public class FlowStack<Coordinator: FlowCoordinatable>: AnyFlowStack {
    public var root: Destination?
    public var parent: (any Coordinatable)?
    public var hasLayerNavigationCoordinator: Bool = false
    public var animation: Animation? = .default
    
    public var destinations: [Destination] = .init()
    
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

extension FlowStack {
    func push(destination: Destination) {
        destinations.append(destination)
    }
    
    func pop() {
        guard !destinations.isEmpty else { return }
        destinations.removeLast()
    }
    
    func popToRoot() {
        destinations.removeAll()
    }
    
    func popToFirst(_ destination: Coordinator.Destinations.Meta) -> Destination? {
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
            self.root = root
        }
    }
}
