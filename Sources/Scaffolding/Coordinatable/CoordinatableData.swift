//
//  CoordinatableData.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftUI

@MainActor
public protocol CoordinatableData: Identifiable {
    associatedtype Coordinator: Coordinatable
                                    
    var parent: (any Coordinatable)? { get set }
    var hasLayerNavigationCoordinator: Bool { get set }
    func setParent(_ parent: any Coordinatable) -> Void
    
    var isSetup: Bool { get set }
    func setup(for coordinator: Coordinator) -> Void
}
