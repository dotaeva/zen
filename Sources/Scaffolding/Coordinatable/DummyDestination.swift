//
//  DummyDestination.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 27.01.2026.
//

import SwiftUI

// MARK: - Dummy Meta

struct DummyDestinationMeta: @MainActor DestinationMeta {
    static func == (lhs: DummyDestinationMeta, rhs: DummyDestinationMeta) -> Bool {
        true
    }
}

// MARK: - Dummy Destinations

@MainActor
struct DummyDestinations: @MainActor Destinationable {
    typealias Meta = DummyDestinationMeta
    typealias Owner = DummyCoordinatable
    
    var meta: DummyDestinationMeta { DummyDestinationMeta() }
    
    func value(for instance: DummyCoordinatable) -> Destination {
        Destination.dummy
    }
}

// MARK: - Dummy Coordinatable

@MainActor
final class DummyCoordinatable: @MainActor Coordinatable {
    typealias Destinations = DummyDestinations
    
    let id = UUID()
    var _dataId: ObjectIdentifier { ObjectIdentifier(self) }
    var parent: (any Coordinatable)?
    var hasLayerNavigationCoordinatable: Bool = false
    
    func view() -> some View {
        EmptyView()
    }
    
    func setHasLayerNavigationCoordinatable(_ value: Bool) {
        hasLayerNavigationCoordinatable = value
    }
    
    func setParent(_ value: any Coordinatable) {
        parent = value
    }
    
    static let shared = DummyCoordinatable()
}

// MARK: - Dummy Destination

extension Destination {
    @MainActor
    static let dummy: Destination = Destination(
        EmptyView(),
        meta: DummyDestinationMeta(),
        parent: DummyCoordinatable.shared
    )
}
