//
//  View+Coordinatable.swift
//  Zen
//
//  Created by Alexandr Valíček on 23.09.2025.
//

import SwiftUI

public extension View {
    func environmentCoordinatable(_ object: Any) -> AnyView {
        let mirror = Mirror(reflecting: object)
        
        guard mirror.displayStyle == .class else {
            return AnyView(self)
        }
        
        let observableObject = object as AnyObject
        
        if let observable = observableObject as? (any AnyObject & Observable) {
            return AnyView(self.environment(observable))
        }
        
        return AnyView(self)
    }
}
