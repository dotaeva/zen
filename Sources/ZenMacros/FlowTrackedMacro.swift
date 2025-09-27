//
//  FlowTrackedMacro.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftSyntax
import SwiftSyntaxMacros

public struct FlowTrackedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return []
    }
}
