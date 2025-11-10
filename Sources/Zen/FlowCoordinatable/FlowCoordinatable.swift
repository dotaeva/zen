//
//  FlowCoordinatable.swift
//  Zen
//
//  Created by Alexandr Valíček on 22.09.2025.
//

import SwiftUI
import Observation
import os.log

public protocol FlowCoordinatable: Coordinatable where ViewType == FlowCoordinatableView {
    var stack: FlowStack<Self> { get }
    var anyStack: any AnyFlowStack { get }
}

@MainActor
public extension FlowCoordinatable {
    var _dataId: ObjectIdentifier {
        stack.id
    }
    
    var anyStack: any AnyFlowStack {
        stack.setup(for: self)
        return stack
    }
    
    func view() -> FlowCoordinatableView {
        stack.setup(for: self)
        return .init(coordinator: self)
    }
    
    var parent: (any Coordinatable)? {
        stack.parent
    }
    
    var hasLayerNavigationCoordinatable: Bool {
        stack.hasLayerNavigationCoordinator
    }
    
    func setHasLayerNavigationCoordinatable(_ value: Bool) {
        stack.hasLayerNavigationCoordinator = value
    }
    
    func setParent(_ parent: any Coordinatable) {
        stack.setParent(parent)
    }
    
    func setRootTransitionAnimation(_ animation: Animation?) {
        stack.setAnimation(animation: animation)
    }
}

// MARK: - Navigation Stack Binding
@MainActor
extension FlowCoordinatable {
    func bindingStack(for destinationType: DestinationType) -> Binding<[Destination]> {
        guard destinationType == .push else {
            return .constant([])
        }
        
        return .init {
            self.flattenDestinations(for: destinationType)
        } set: { newValue in
            self.reconstructDestinations(from: newValue, for: destinationType)
        }
    }
}

// MARK: - Modal Handling
@MainActor
extension FlowCoordinatable {
    func modalDestinations(for destinationType: DestinationType) -> [Destination] {
        guard destinationType == .sheet || destinationType == .fullScreenCover else {
            return []
        }
        
        var flattened: [Destination] = []
        
        // Check root destination first
        if let rootDest = self.anyStack.root {
            traverseCoordinatable(rootDest.coordinatable) { nestedFlow in
                flattened.append(contentsOf: nestedFlow.modalDestinations(for: destinationType))
            }
        }
        
        // Then check self destinations
        for destination in self.anyStack.destinations {
            if destination.pushType == destinationType {
                flattened.append(destination)
            }
            
            traverseCoordinatable(destination.coordinatable) { nestedFlow in
                flattened.append(contentsOf: nestedFlow.modalDestinations(for: destinationType))
            }
        }
        
        return flattened
    }
    
    func removeModalDestination(withId id: UUID, type: DestinationType) {
        // Check root destination first
        if let rootDest = self.anyStack.root {
            traverseCoordinatable(rootDest.coordinatable) { nestedFlow in
                nestedFlow.removeModalDestination(withId: id, type: type)
            }
        }
        
        // Then check self destinations
        anyStack.destinations.removeAll { $0.id == id && $0.pushType == type }
        
        for destination in anyStack.destinations {
            traverseCoordinatable(destination.coordinatable) { nestedFlow in
                nestedFlow.removeModalDestination(withId: id, type: type)
            }
        }
    }
}

// MARK: - Flatten & Reconstruct
@MainActor
private extension FlowCoordinatable {
    func flattenDestinations(for destinationType: DestinationType) -> [Destination] {
        var flattened: [Destination] = []
        
        func flattenRecursively(_ destinations: [Destination]) {
            for destination in destinations {
                guard destination.pushType != .sheet && destination.pushType != .fullScreenCover else {
                    continue
                }
                
                if destination.pushType == destinationType {
                    flattened.append(destination)
                }
                
                if destination.pushType == .push {
                    traverseCoordinatable(destination.coordinatable) { nestedFlow in
                        flattenRecursively(nestedFlow.anyStack.destinations)
                    }
                }
            }
        }
        
        // Handle root
        if let rootDest = self.anyStack.root {
            traverseCoordinatable(rootDest.coordinatable) { rootFlow in
                if rootFlow.hasLayerNavigationCoordinatable {
                    flattenRecursively(rootFlow.anyStack.destinations)
                }
            }
        }
        
        flattenRecursively(self.anyStack.destinations)
        
        return flattened
    }

    private func reconstructDestinations(from flattenedDestinations: [Destination], for destinationType: DestinationType) {
        var flatIndex = 0
        
        func reconstructRecursively(for coordinator: any FlowCoordinatable) -> [Destination] {
            var newDestinations: [Destination] = []
            
            for originalDestination in coordinator.anyStack.destinations {
                if originalDestination.pushType == .sheet || originalDestination.pushType == .fullScreenCover {
                    newDestinations.append(originalDestination)
                    continue
                }
                
                if originalDestination.pushType == destinationType {
                    if flatIndex < flattenedDestinations.count {
                        let flatDest = flattenedDestinations[flatIndex]
                        
                        // Check if this destination matches the current flattened one
                        if flatDest.id == originalDestination.id {
                            newDestinations.append(flatDest)
                            flatIndex += 1
                            
                            // Process nested coordinator if this is a push destination
                            if originalDestination.pushType == .push {
                                traverseCoordinatable(originalDestination.coordinatable) { nestedFlow in
                                    let reconstructedNested = reconstructRecursively(for: nestedFlow)
                                    nestedFlow.anyStack.destinations = reconstructedNested
                                }
                            }
                        }
                        // Don't add this destination - it was popped
                    }
                    // Don't add - this destination was popped
                } else if originalDestination.pushType == .push {
                    // For non-matching push types, we need to check if this should still exist
                    // by seeing if any of the remaining flattened destinations are within this coordinator
                    
                    var hasNestedDestinations = false
                    let savedFlatIndex = flatIndex
                    
                    // Check if any remaining flattened destinations belong to this nested coordinator
                    traverseCoordinatable(originalDestination.coordinatable) { nestedFlow in
                        // Collect all destination IDs that belong to this nested flow
                        var nestedDestinationIds = Set<UUID>()
                        
                        @MainActor func collectNestedIds(from flow: any FlowCoordinatable) {
                            for dest in flow.anyStack.destinations {
                                if dest.pushType != .sheet && dest.pushType != .fullScreenCover {
                                    nestedDestinationIds.insert(dest.id)
                                    
                                    if dest.pushType == .push {
                                        traverseCoordinatable(dest.coordinatable) { innerFlow in
                                            collectNestedIds(from: innerFlow)
                                        }
                                    }
                                }
                            }
                        }
                        
                        collectNestedIds(from: nestedFlow)
                        
                        // Count how many of the remaining flattened destinations belong to this nested flow
                        var tempIndex = savedFlatIndex
                        var nestedCount = 0
                        
                        while tempIndex < flattenedDestinations.count {
                            if nestedDestinationIds.contains(flattenedDestinations[tempIndex].id) {
                                nestedCount += 1
                                tempIndex += 1
                            } else {
                                // This destination doesn't belong to this nested coordinator
                                break
                            }
                        }
                        
                        if nestedCount > 0 {
                            hasNestedDestinations = true
                            let reconstructedNested = reconstructRecursively(for: nestedFlow)
                            nestedFlow.anyStack.destinations = reconstructedNested
                        } else {
                            // Clear the nested destinations
                            nestedFlow.anyStack.destinations = []
                        }
                    }
                    
                    if hasNestedDestinations {
                        newDestinations.append(originalDestination)
                    }
                } else {
                    newDestinations.append(originalDestination)
                }
            }
            
            return newDestinations
        }
        
        if let rootDest = self.anyStack.root {
            traverseCoordinatable(rootDest.coordinatable) { rootFlow in
                if rootFlow.hasLayerNavigationCoordinatable {
                    if !flattenedDestinations.isEmpty {
                        let reconstructedRoot = reconstructRecursively(for: rootFlow)
                        rootFlow.anyStack.destinations = reconstructedRoot
                    } else {
                        rootFlow.anyStack.destinations = []
                    }
                }
            }
        }
        
        let reconstructed = reconstructRecursively(for: self)
        self.anyStack.destinations = reconstructed
    }
}

@MainActor
private extension FlowCoordinatable {
    func traverseCoordinatable(_ coordinatable: (any Coordinatable)?, action: (any FlowCoordinatable) -> Void) {
        guard let coordinatable = coordinatable else { return }
        
        if let flowCoordinator = coordinatable as? any FlowCoordinatable {
            action(flowCoordinator)
        } else if let tabCoordinator = coordinatable as? any TabCoordinatable {
            if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
               let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
               let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                action(nestedFlow)
            }
        } else if let rootCoordinator = coordinatable as? any RootCoordinatable,
                  let rootDestination = rootCoordinator.anyRoot.root {
            traverseCoordinatable(rootDestination.coordinatable, action: action)
        }
    }
    
    func checkForMultipleModals(pushType: DestinationType) {
        func findLayerFlowParent(lookup: (any Coordinatable)?) -> any FlowCoordinatable {
            if let flowCoordinatable = lookup as? (any FlowCoordinatable) {
                if !flowCoordinatable.anyStack.hasLayerNavigationCoordinator {
                    return flowCoordinatable
                }
                return findLayerFlowParent(lookup: flowCoordinatable.anyStack.parent)
            }
            return self
        }
        
        let existingModals = findLayerFlowParent(lookup: self).modalDestinations(for: pushType)
        
        if existingModals.count > 1 {
            let logger = Logger(subsystem: "Zen", category: "Modal")
            logger.critical("Zen: Currently, only presenting a single sheet is supported.\nThe next sheet will be presented when the currently presented sheet gets dismissed.")
        }
    }
}

@MainActor
public extension FlowCoordinatable {
    @discardableResult
    func setRoot(_ destination: Destinations, animation: Animation? = nil) -> Self {
        let dest = destination.value(for: self)
        dest.coordinatable?.setParent(self)
        stack.setRoot(root: dest, animation: animation)
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
        stack.setRoot(root: dest, animation: animation)
        castAndExecute(from: dest, action: value)
        return self
    }
    
    @discardableResult
    func route(
        to destination: Destinations,
        as pushType: DestinationType = .push,
        onDismiss: @escaping () -> Void = { }
    ) -> Self {
        performRoute(to: destination, as: pushType, onDismiss: onDismiss)
        return self
    }
    
    @discardableResult
    func route<T>(
        to destination: Destinations,
        as pushType: DestinationType = .push,
        onDismiss: @escaping () -> Void = { },
        value: @escaping (T) -> Void
    ) -> Self {
        let dest = performRoute(to: destination, as: pushType, onDismiss: onDismiss)
        castAndExecute(from: dest, action: value)
        return self
    }
    
    @discardableResult
    func pop() -> Self {
        stack.pop()
        return self
    }
    
    @discardableResult
    func popToRoot() -> Self {
        stack.popToRoot()
        return self
    }
    
    @discardableResult
    func popToFirst(_ destination: Destinations.Meta) -> Self {
        _ = stack.popToFirst(destination)
        return self
    }
    
    @discardableResult
    func popToFirst<T>(
        _ destination: Destinations.Meta,
        value: @escaping (T) -> Void
    ) -> Self {
        guard let dest = stack.popToFirst(destination) else { return self }
        castAndExecute(from: dest, action: value)
        return self
    }
    
    @discardableResult
    func popToLast(_ destination: Destinations.Meta) -> Self {
        _ = stack.popToLast(destination)
        return self
    }
    
    @discardableResult
    func popToLast<T>(
        _ destination: Destinations.Meta,
        value: @escaping (T) -> Void
    ) -> Self {
        guard let dest = stack.popToLast(destination) else { return self }
        castAndExecute(from: dest, action: value)
        return self
    }
    
    func isInStack(_ destination: Destinations.Meta) -> Bool {
        stack.destinations.contains { $0.meta as! Self.Destinations.Meta == destination }
    }
}

@MainActor
private extension FlowCoordinatable {
    @discardableResult
    func performRoute(
        to destination: Destinations,
        as pushType: DestinationType,
        onDismiss: @escaping () -> Void
    ) -> Destination {
        var dest = destination.value(for: self)
        
        dest.setOnDismiss(onDismiss)
        dest.setPushType(pushType)
        dest.coordinatable?.setHasLayerNavigationCoordinatable(pushType == .push)
        dest.coordinatable?.setParent(self)
        
        stack.push(destination: dest)
        
        checkForMultipleModals(pushType: pushType)
        return dest
    }
    
    func castAndExecute<T>(from dest: Destination, action: @escaping (T) -> Void) {
        if let coordinatable = dest.coordinatable as? T {
            action(coordinatable)
        } else if let view = dest.view as? T {
            action(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
    }
}

public struct FlowCoordinatableView: CoordinatableView {
    private let _coordinator: any FlowCoordinatable
    
    public var coordinator: any Coordinatable {
        _coordinator
    }
    
    init(coordinator: any FlowCoordinatable) {
        self._coordinator = coordinator
    }
    
    @ViewBuilder
    private func coordinatorView() -> some View {
        if let rootView = _coordinator.anyStack.root?.view {
            flowCoordinatableView(view: AnyView(rootView))
        } else if let c = _coordinator.anyStack.root?.coordinatable {
            flowCoordinatableView(view: AnyView(c.view()))
        } else {
            EmptyView()
        }
    }
    
    private func flowCoordinatableView(view: AnyView) -> some View {
        NavigationStack(path: _coordinator.bindingStack(for: .push)) {
            view
                .navigationDestination(for: Destination.self, destination: wrappedView)
        }
        .applySheets(from: _coordinator, modalContent: wrappedView)
        .applyFullScreenCovers(from: _coordinator, modalContent: wrappedView)
    }
    
    public var body: some View {
        _coordinator.customize(
            AnyView(
                Group {
                    if _coordinator.anyStack.hasLayerNavigationCoordinator {
                        if let rootView = _coordinator.anyStack.root?.view {
                            AnyView(rootView)
                        } else if let c = _coordinator.anyStack.root?.coordinatable {
                            AnyView(c.view())
                                .environmentCoordinatable(c)
                        } else {
                            EmptyView()
                        }
                    } else {
                        coordinatorView()
                    }
                }
            )
        )
        .environmentCoordinatable(_coordinator)
        .id(_coordinator.anyStack.id)
    }
}
