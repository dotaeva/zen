//
//  Plugin.swift
//  Scaffolding
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ScaffoldingPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ScaffoldableMacro.self,
        ScaffoldingIgnoredMacro.self,
    ]
}
