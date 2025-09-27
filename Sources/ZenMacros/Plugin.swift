//
//  Plugin.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ZenPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FlowMacro.self,
        FlowTrackedMacro.self,
        FlowIgnoredMacro.self,
    ]
}
