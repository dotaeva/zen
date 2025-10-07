//
//  Coordinatable.swift
//  Zen
//
//  Created by Alexandr Valíček on 22.09.2025.
//

import SwiftUI

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
        if let parent = parent as? (any FlowCoordinatable) {
            let selfId = AnyHashable(self.id)
            parent.anyStack.destinations.removeAll(where: {
                guard let coordinatableId = $0.coordinatable?.id else { return false }
                return AnyHashable(coordinatableId) == selfId
            })
        }
    }
    
    func resolveMeta(_ meta: DestinationMeta) -> Destinations.Meta? {
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
