//
//  CoordinatableView.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 29.09.2025.
//

import SwiftUI

@MainActor
public protocol CoordinatableView: View {
    var coordinator: any Coordinatable { get }
}

@MainActor
public extension CoordinatableView {
    @ViewBuilder
    func wrappedView(_ destination: Destination) -> some View {
        let content = Group {
            if let view = destination.view {
                AnyView(view.environmentCoordinatable(destination.parent))
            } else if let c = destination.coordinatable {
                AnyView(c.view())
            } else {
                AnyView(EmptyView())
            }
        }
        
        if destination.parent._dataId != coordinator._dataId {
            AnyView(destination.parent.customizeErased(AnyView(content)))
        } else {
            AnyView(content)
        }
    }
}
