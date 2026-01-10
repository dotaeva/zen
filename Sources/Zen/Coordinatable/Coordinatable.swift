//
//  Coordinatable.swift
//  Zen
//
//  Created by Alexandr Valíček on 22.09.2025.
//

import SwiftUI
import os.log

@MainActor
public protocol Coordinatable: Identifiable {
    associatedtype Destinations: Destinationable where Destinations.Owner == Self
    associatedtype ViewType: View
    associatedtype CustomizeContentView: View
    
    var _dataId: ObjectIdentifier { get }
    var parent: (any Coordinatable)? { get }
    var hasLayerNavigationCoordinatable: Bool { get }
    func view() -> ViewType
    func setHasLayerNavigationCoordinatable(_ value: Bool)
    func setParent(_ value: any Coordinatable)
    func customize(_ view: AnyView) -> CustomizeContentView
}

public extension Coordinatable {
    func customize(_ view: AnyView) -> some View {
        view
    }
    
    func dismissCoordinator() {
        let logger = Logger(subsystem: "Zen", category: "Dismissal")
        
        if let parent = parent as? (any TabCoordinatable) {
            logger.critical("Zen: The coordinator you're trying to dismiss is a TabView child, it will not be dismissed.")
            return
        }
        
        if let parent = parent as? (any RootCoordinatable) {
            parent.parent?.dismissCoordinator()
            return
        }
        
        if let parent = parent as? (any FlowCoordinatable) {
            let selfId = AnyHashable(self.id)
            
            if let root = parent.anyStack.root,
               let rootCoordinatable = root.coordinatable?.id,
               AnyHashable(rootCoordinatable) == selfId {
                parent.dismissCoordinator()
                return
            }
            
            parent.anyStack.destinations.removeAll(where: {
                guard let coordinatableId = $0.coordinatable?.id else { return false }
                return AnyHashable(coordinatableId) == selfId
            })
        }
    }
    
    func resolveMeta(_ meta: any DestinationMeta) -> Destinations.Meta? {
        return meta as? Self.Destinations.Meta
    }
}

extension Coordinatable {
    func customizeErased(_ view: AnyView) -> AnyView {
        AnyView(customize(view))
    }
}

public protocol Destinationable {
    associatedtype Meta: DestinationMeta
    associatedtype Owner
    
    var meta: Meta { get }
    @MainActor func value(for instance: Owner) -> Destination
}
