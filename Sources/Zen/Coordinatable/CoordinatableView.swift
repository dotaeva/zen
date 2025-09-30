//
//  CoordinatableView.swift
//  Zen
//
//  Created by Alexandr Valíček on 29.09.2025.
//

import SwiftUI

public protocol CoordinatableView: View {
    var coordinator: any Coordinatable { get }
}

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
