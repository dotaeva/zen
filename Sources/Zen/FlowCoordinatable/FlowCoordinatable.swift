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

@MainActor
extension FlowCoordinatable {
    func bindingStack(for destinationType: DestinationType) -> Binding<[Destination]> {
        guard destinationType == .push else {
            return .constant([])
        }
        
        return .init {
            return self.flattenDestinations(for: destinationType)
        } set: { newValue in
            self.reconstructDestinations(from: newValue, for: destinationType)
        }
    }
    
    func modalDestinations(for destinationType: DestinationType) -> [Destination] {
        guard destinationType == .sheet || destinationType == .fullScreenCover else {
            return []
        }
        
        var flattened: [Destination] = []
        
        for destination in self.anyStack.destinations {
            if destination.pushType == destinationType {
                flattened.append(destination)
            }
            
            // Handle nested FlowCoordinatable
            if let nestedCoordinator = destination.coordinatable as? any FlowCoordinatable {
                let nestedModals = nestedCoordinator.modalDestinations(for: destinationType)
                flattened.append(contentsOf: nestedModals)
            }
            // Handle TabCoordinatable
            else if let tabCoordinator = destination.coordinatable as? any TabCoordinatable {
                if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
                   let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
                   let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                    let nestedModals = nestedFlow.modalDestinations(for: destinationType)
                    flattened.append(contentsOf: nestedModals)
                }
            }
            // Handle RootCoordinatable
            else if let rootCoordinator = destination.coordinatable as? any RootCoordinatable {
                if let rootDestination = rootCoordinator.anyRoot.root {
                    let nestedModals = modalDestinationsFromRootDestination(rootDestination, for: destinationType)
                    flattened.append(contentsOf: nestedModals)
                }
            }
        }
        
        return flattened
    }
    
    func removeModalDestination(withId id: UUID, type: DestinationType) {
        anyStack.destinations.removeAll { $0.id == id && $0.pushType == type }
        
        for destination in anyStack.destinations {
            // Handle nested FlowCoordinatable
            if let nestedCoordinator = destination.coordinatable as? any FlowCoordinatable {
                nestedCoordinator.removeModalDestination(withId: id, type: type)
            }
            // Handle TabCoordinatable
            else if let tabCoordinator = destination.coordinatable as? any TabCoordinatable {
                if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
                   let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
                   let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                    nestedFlow.removeModalDestination(withId: id, type: type)
                }
            }
            // Handle RootCoordinatable
            else if let rootCoordinator = destination.coordinatable as? any RootCoordinatable {
                removeModalDestinationFromRootCoordinator(rootCoordinator, withId: id, type: type)
            }
        }
    }
    
    private func modalDestinationsFromRootDestination(_ destination: Destination, for destinationType: DestinationType) -> [Destination] {
        var modals: [Destination] = []
        
        if let nestedFlow = destination.coordinatable as? any FlowCoordinatable {
            let nestedModals = nestedFlow.modalDestinations(for: destinationType)
            modals.append(contentsOf: nestedModals)
        } else if let tabCoordinator = destination.coordinatable as? any TabCoordinatable {
            if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
               let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
               let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                let nestedModals = nestedFlow.modalDestinations(for: destinationType)
                modals.append(contentsOf: nestedModals)
            }
        } else if let rootCoordinator = destination.coordinatable as? any RootCoordinatable {
            if let rootDestination = rootCoordinator.anyRoot.root {
                let nestedModals = modalDestinationsFromRootDestination(rootDestination, for: destinationType)
                modals.append(contentsOf: nestedModals)
            }
        }
        
        return modals
    }
    
    private func removeModalDestinationFromRootCoordinator(_ rootCoordinator: any RootCoordinatable, withId id: UUID, type: DestinationType) {
        guard let rootDestination = rootCoordinator.anyRoot.root else { return }
        
        if let nestedFlow = rootDestination.coordinatable as? any FlowCoordinatable {
            nestedFlow.removeModalDestination(withId: id, type: type)
        } else if let tabCoordinator = rootDestination.coordinatable as? any TabCoordinatable {
            if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
               let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
               let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                nestedFlow.removeModalDestination(withId: id, type: type)
            }
        } else if let nestedRootCoordinator = rootDestination.coordinatable as? any RootCoordinatable {
            removeModalDestinationFromRootCoordinator(nestedRootCoordinator, withId: id, type: type)
        }
    }
    
    private func flattenDestinations(for destinationType: DestinationType) -> [Destination] {
        var flattened: [Destination] = []
        
        func flattenRecursively(_ destinations: [Destination]) {
            for (index, destination) in destinations.enumerated() {
                if destination.pushType == .sheet || destination.pushType == .fullScreenCover {
                    continue
                }
                
                if destination.pushType == destinationType {
                    flattened.append(destination)
                }
                
                if destination.pushType == .push {
                    if let nestedCoordinator = destination.coordinatable as? any FlowCoordinatable {
                        flattenRecursively(nestedCoordinator.anyStack.destinations)
                    } else if let tabCoordinator = destination.coordinatable as? any TabCoordinatable {
                        if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
                           let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
                           let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                            flattenRecursively(nestedFlow.anyStack.destinations)
                        }
                    } else if let rootCoordinator = destination.coordinatable as? any RootCoordinatable {
                        flattenFromRootCoordinator(rootCoordinator)
                    }
                }
            }
        }
        
        func flattenFromRootCoordinator(_ rootCoordinator: any RootCoordinatable) {
            guard let rootDestination = rootCoordinator.anyRoot.root else {
                return
            }
            
            if let nestedFlow = rootDestination.coordinatable as? any FlowCoordinatable {
                flattenRecursively(nestedFlow.anyStack.destinations)
            } else if let tabCoordinator = rootDestination.coordinatable as? any TabCoordinatable {
                if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
                   let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
                   let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                    flattenRecursively(nestedFlow.anyStack.destinations)
                }
            } else if let nestedRootCoordinator = rootDestination.coordinatable as? any RootCoordinatable {
                flattenFromRootCoordinator(nestedRootCoordinator)
            }
        }
        
        if let rootDest = self.anyStack.root {
            if let rootCoord = rootDest.coordinatable as? any FlowCoordinatable {
                if rootCoord.hasLayerNavigationCoordinatable {
                    flattenRecursively(rootCoord.anyStack.destinations)
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
            
            for (index, originalDestination) in coordinator.anyStack.destinations.enumerated() {
                if originalDestination.pushType == .sheet || originalDestination.pushType == .fullScreenCover {
                    newDestinations.append(originalDestination)
                    continue
                }
                
                if originalDestination.pushType == destinationType {
                    if flatIndex < flattenedDestinations.count {
                        let flatDest = flattenedDestinations[flatIndex]
                        newDestinations.append(flatDest)
                        flatIndex += 1
                    }
                } else if originalDestination.pushType == .push {
                    if let nestedCoordinator = originalDestination.coordinatable as? any FlowCoordinatable {
                        let reconstructedNested = reconstructRecursively(for: nestedCoordinator)
                        nestedCoordinator.anyStack.destinations = reconstructedNested
                    } else if let tabCoordinator = originalDestination.coordinatable as? any TabCoordinatable {
                        if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
                           let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
                           let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                            let reconstructedNested = reconstructRecursively(for: nestedFlow)
                            nestedFlow.anyStack.destinations = reconstructedNested
                        }
                    } else if let rootCoordinator = originalDestination.coordinatable as? any RootCoordinatable {
                        reconstructFromRootCoordinator(rootCoordinator)
                    }
                    
                    newDestinations.append(originalDestination)
                } else {
                    newDestinations.append(originalDestination)
                }
            }
            
            return newDestinations
        }
        
        func reconstructFromRootCoordinator(_ rootCoordinator: any RootCoordinatable) {
            guard let rootDestination = rootCoordinator.anyRoot.root else {
                return
            }
            
            if let nestedFlow = rootDestination.coordinatable as? any FlowCoordinatable {
                let reconstructedNested = reconstructRecursively(for: nestedFlow)
                nestedFlow.anyStack.destinations = reconstructedNested
            } else if let tabCoordinator = rootDestination.coordinatable as? any TabCoordinatable {
                if let selectedTabId = tabCoordinator.anyTabItems.selectedTab,
                   let selectedTab = tabCoordinator.anyTabItems.tabs.first(where: { $0.id == selectedTabId }),
                   let nestedFlow = selectedTab.coordinatable as? any FlowCoordinatable {
                    let reconstructedNested = reconstructRecursively(for: nestedFlow)
                    nestedFlow.anyStack.destinations = reconstructedNested
                }
            } else if let nestedRootCoordinator = rootDestination.coordinatable as? any RootCoordinatable {
                reconstructFromRootCoordinator(nestedRootCoordinator)
            }
        }
        
        // Handle if root is a FlowCoordinatable and reconstruct its destinations
        if let rootDest = self.anyStack.root,
           let rootCoord = rootDest.coordinatable as? any FlowCoordinatable,
           rootCoord.hasLayerNavigationCoordinatable {
            let reconstructedRoot = reconstructRecursively(for: rootCoord)
            rootCoord.anyStack.destinations = reconstructedRoot
        }
        
        let reconstructed = reconstructRecursively(for: self)
        
        self.anyStack.destinations = reconstructed
    }
    
    private func checkForMultipleModals(pushType: DestinationType) {
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
        
        stack.setRoot(root: dest, animation: animation)
        
        if dest.coordinatable != nil, let coordinatable = dest.coordinatable as? T {
            value(coordinatable)
        } else if let view = dest.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func route(
        to destination: Destinations,
        as pushType: DestinationType = .push,
        onDismiss: @escaping () -> Void = { }
    ) -> Self {
        var dest = destination.value(for: self)
        
        dest.setOnDismiss(onDismiss)
        dest.setPushType(pushType)
        dest.coordinatable?.setHasLayerNavigationCoordinatable(pushType == .push)
        dest.coordinatable?.setParent(self)
        
        stack.push(destination: dest)
        
        checkForMultipleModals(pushType: pushType)
        return self
    }
    
    @discardableResult
    func route<T>(
        to destination: Destinations,
        as pushType: DestinationType = .push,
        onDismiss: @escaping () -> Void = { },
        value: @escaping (T) -> Void,
    ) -> Self {
        var dest = destination.value(for: self)
        
        dest.setOnDismiss(onDismiss)
        dest.setPushType(pushType)
        dest.coordinatable?.setHasLayerNavigationCoordinatable(pushType == .push)
        dest.coordinatable?.setParent(self)
        
        stack.push(destination: dest)
        
        checkForMultipleModals(pushType: pushType)
        
        if dest.coordinatable != nil, let coordinatable = dest.coordinatable as? T {
            value(coordinatable)
        } else if let view = dest.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
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
        let _ = stack.popToFirst(destination)
        
        return self
    }
    
    @discardableResult
    func popToFirst<T>(
        _ destination: Destinations.Meta,
        value: @escaping (T) -> Void,
    ) -> Self {
        guard let dest = stack.popToFirst(destination) else { return self }
        
        if dest.coordinatable != nil, let coordinatable = dest.coordinatable as? T {
            value(coordinatable)
        } else if let view = dest.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    @discardableResult
    func popToLast(_ destination: Destinations.Meta) -> Self {
        let _ = stack.popToLast(destination)
        
        return self
    }
    
    @discardableResult
    func popToLast<T>(
        _ destination: Destinations.Meta,
        value: @escaping (T) -> Void,
    ) -> Self {
        guard let dest = stack.popToLast(destination) else { return self }
        
        if dest.coordinatable != nil, let coordinatable = dest.coordinatable as? T {
            value(coordinatable)
        } else if let view = dest.view as? T {
            value(view)
        } else {
            fatalError("Could not cast to type \(T.self)")
        }
        
        return self
    }
    
    func isInStack(_ destination: Destinations.Meta) -> Bool {
        return stack.destinations.contains(where: { $0.meta as! Self.Destinations.Meta == destination })
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
