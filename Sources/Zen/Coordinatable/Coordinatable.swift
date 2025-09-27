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
    
    var parent: (any Coordinatable)? { get }
    var hasLayerNavigationCoordinatable: Bool { get }
    func view() -> ViewType
    func setHasLayerNavigationCoordinatable(_ value: Bool)
    func setParent(_ value: any Coordinatable)
    func customize(_ view: AnyView) -> AnyView
}

public extension Coordinatable {
    func customize(_ view: AnyView) -> AnyView {
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
}

public protocol Destinationable {
    associatedtype Meta: DestinationMeta
    associatedtype Owner
    
    var meta: Meta { get }
    @MainActor func value(for instance: Owner) -> Destination
}
