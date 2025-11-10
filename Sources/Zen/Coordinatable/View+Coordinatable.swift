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
            var coordinators: [any AnyObject & Observable] = [observable]
            
            if let coordinatable = observable as? any Coordinatable {
                var currentParent = coordinatable.parent
                while let parent = currentParent {
                    if let parentObservable = parent as? (any AnyObject & Observable) {
                        coordinators.append(parentObservable)
                    }
                    currentParent = parent.parent
                }
            }
            
            var result: any View = self
            for coordinator in coordinators {
                result = result.environment(coordinator)
            }
            
            return AnyView(result)
        }
        
        return AnyView(self)
    }
}
