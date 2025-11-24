//
//  FlowMacro.swift
//  Zen
//
//  Created by Alexandr Valíček on 26.09.2025.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

public struct FlowMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw FlowMacroError.onlyApplicableToClass
        }
        
        let className = classDecl.name.text
        let coordinatableType = try determineCoordinatableType(from: classDecl)
        let isPublic = classDecl.modifiers.contains { modifier in
            modifier.name.text == "public"
        }
        
        let functions = extractFunctions(from: classDecl)
        let trackedFunctions = try filterTrackedFunctions(functions, coordinatableType: coordinatableType, context: context)
        
        let destinationsEnum = try generateDestinationsEnum(
            className: className,
            functions: trackedFunctions,
            isPublic: isPublic
        )
        
        return [DeclSyntax(destinationsEnum)]
    }
    
    
    private static func determineCoordinatableType(from classDecl: ClassDeclSyntax) throws -> CoordinatableType {
        let inheritanceTypes = classDecl.inheritanceClause?.inheritedTypes.compactMap { type in
            type.type.as(IdentifierTypeSyntax.self)?.name.text
        } ?? []
        
        if inheritanceTypes.contains("TabCoordinatable") {
            return .tab
        } else if inheritanceTypes.contains("RootCoordinatable") {
            return .root
        } else if inheritanceTypes.contains("FlowCoordinatable") {
            return .flow
        } else {
            throw FlowMacroError.mustConformToCoordinatable
        }
    }
    
    private static func extractFunctions(from classDecl: ClassDeclSyntax) -> [FunctionDeclSyntax] {
        return classDecl.memberBlock.members.compactMap { member in
            member.decl.as(FunctionDeclSyntax.self)
        }.filter { function in
            !["init", "deinit"].contains(function.name.text)
        }
    }
    
    private static func filterTrackedFunctions(
        _ functions: [FunctionDeclSyntax],
        coordinatableType: CoordinatableType,
        context: some MacroExpansionContext
    ) throws -> [TrackedFunction] {
        var trackedFunctions: [TrackedFunction] = []
        
        for function in functions {
            let hasFlowTracked = hasAttribute(function, named: "FlowTracked")
            let hasFlowIgnored = hasAttribute(function, named: "FlowIgnored")
            
            if hasFlowIgnored {
                continue
            }
            
            let returnTypeInfo = try parseReturnType(function.signature.returnClause?.type)
            let shouldAutoTrack = shouldAutoTrackFunction(returnType: returnTypeInfo)
            
            if hasFlowTracked || shouldAutoTrack {
                if coordinatableType != .tab && (returnTypeInfo == .coordinatableViewTuple || returnTypeInfo == .viewViewTuple) {
                    context.diagnose(Diagnostic(
                        node: function,
                        message: FlowMacroWarning.tupleIgnoredInNonTabCoordinatable
                    ))
                }
                
                let trackedFunction = try TrackedFunction(
                    function: function,
                    returnType: returnTypeInfo
                )
                trackedFunctions.append(trackedFunction)
            }
        }
        
        return trackedFunctions
    }
    
    private static func hasAttribute(_ function: FunctionDeclSyntax, named attributeName: String) -> Bool {
        return function.attributes.contains { attribute in
            if let identifierType = attribute.as(AttributeSyntax.self)?
                .attributeName.as(IdentifierTypeSyntax.self) {
                return identifierType.name.text == attributeName
            }
            return false
        }
    }
    
    private static func parseReturnType(_ type: TypeSyntax?) throws -> ReturnTypeInfo {
        guard let type = type else {
            return .void
        }
        
        let typeString = type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if typeString.hasPrefix("some View") || typeString == "some View" {
            return .someView
        } else if typeString.hasPrefix("any Coordinatable") || typeString == "any Coordinatable" {
            return .anyCoordinatable
        } else if typeString.contains("(any Coordinatable, some View)") {
            return .coordinatableViewTuple
        } else if typeString.contains("(some View, some View)") {
            return .viewViewTuple
        }
        
        return .other
    }
    
    private static func shouldAutoTrackFunction(returnType: ReturnTypeInfo) -> Bool {
        switch returnType {
        case .someView, .anyCoordinatable, .coordinatableViewTuple, .viewViewTuple:
            return true
        case .void, .other:
            return false
        }
    }
    
    private static func generateDestinationsEnum(
        className: String,
        functions: [TrackedFunction],
        isPublic: Bool
    ) throws -> EnumDeclSyntax {
        
        // Generate Meta enum cases
        var metaCases: [EnumCaseElementSyntax] = []
        for function in functions {
            metaCases.append(EnumCaseElementSyntax(name: .identifier(function.name)))
        }
        
        // Generate main enum cases
        var mainCases: [EnumCaseDeclSyntax] = []
        for function in functions {
            mainCases.append(try generateEnumCaseDecl(for: function))
        }
        
        // Generate meta switch cases
        var metaSwitchCases: [SwitchCaseSyntax] = []
        for function in functions {
            metaSwitchCases.append(SwitchCaseSyntax(
                "case .\(raw: function.name): return .\(raw: function.name)"
            ))
        }
        
        // Generate value switch cases
        var valueSwitchCases: [SwitchCaseSyntax] = []
        for function in functions {
            valueSwitchCases.append(try generateValueCaseSwitch(for: function))
        }
        
        let accessModifier = isPublic ? "public " : ""
        
        let destinationsEnum = try EnumDeclSyntax("\(raw: accessModifier)enum Destinations: Destinationable") {
            // typealias Owner = ClassName
            DeclSyntax("\(raw: accessModifier)typealias Owner = \(raw: className)")
            
            // Meta enum
            try EnumDeclSyntax("\(raw: accessModifier)enum Meta: DestinationMeta") {
                for caseElement in metaCases {
                    EnumCaseDeclSyntax {
                        caseElement
                    }
                }
            }
            
            // Main cases
            for caseDecl in mainCases {
                caseDecl
            }
            
            // meta computed property
            try VariableDeclSyntax("\(raw: accessModifier)var meta: Meta") {
                AccessorDeclSyntax(accessorSpecifier: .keyword(.get)) {
                    SwitchExprSyntax(subject: DeclReferenceExprSyntax(baseName: .keyword(.`self`))) {
                        for switchCase in metaSwitchCases {
                            switchCase
                        }
                    }
                }
            }
            
            // value function
            try FunctionDeclSyntax("\(raw: accessModifier)func value(for instance: Owner) -> Destination") {
                SwitchExprSyntax(subject: DeclReferenceExprSyntax(baseName: .keyword(.`self`))) {
                    for switchCase in valueSwitchCases {
                        switchCase
                    }
                }
            }
        }
        
        return destinationsEnum
    }
    
    private static func generateEnumCaseDecl(for function: TrackedFunction) throws -> EnumCaseDeclSyntax {
        let docTrivia = generateDocumentationTrivia(for: function)
        
        if function.parameters.isEmpty {
            let enumCaseDecl = EnumCaseDeclSyntax {
                EnumCaseElementSyntax(name: .identifier(function.name))
            }
            
            return enumCaseDecl.with(\.leadingTrivia, docTrivia)
        } else {
            let params = function.parameters.enumerated().map { (index, param) in
                let isLast = index == function.parameters.count - 1
                
                if let label = param.label {
                    return EnumCaseParameterSyntax(
                        firstName: .identifier(label),
                        colon: .colonToken(),
                        type: IdentifierTypeSyntax(name: .identifier(param.type)),
                        trailingComma: isLast ? nil : .commaToken()
                    )
                } else {
                    return EnumCaseParameterSyntax(
                        type: IdentifierTypeSyntax(name: .identifier(param.type)),
                        trailingComma: isLast ? nil : .commaToken()
                    )
                }
            }
            
            let enumCaseDecl = EnumCaseDeclSyntax {
                EnumCaseElementSyntax(
                    name: .identifier(function.name),
                    parameterClause: EnumCaseParameterClauseSyntax(
                        parameters: EnumCaseParameterListSyntax(params)
                    )
                )
            }
            
            return enumCaseDecl.with(\.leadingTrivia, docTrivia)
        }
    }
    
    private static func generateDocumentationTrivia(for function: TrackedFunction) -> Trivia {
        let returnTypeString = getActualReturnTypeString(from: function.originalFunction)
        let functionBodyLines = extractFunctionBodyLines(from: function.originalFunction)
        
        var triviaPieces: [TriviaPiece] = [
            .docLineComment("/// ```swift"),
            .newlines(1),
            .docLineComment("/// \(returnTypeString)"),
            .newlines(1),
            .docLineComment("/// ```"),
            .newlines(1),
            .docLineComment("///"),
            .newlines(1),
            .docLineComment("/// Function body"),
            .newlines(1),
            .docLineComment("/// ```swift"),
            .newlines(1)
        ]
        
        for line in functionBodyLines {
            triviaPieces.append(.docLineComment("/// \(line)"))
            triviaPieces.append(.newlines(1))
        }
        
        triviaPieces.append(.docLineComment("/// ```"))
        triviaPieces.append(.newlines(1))
        
        return Trivia(pieces: triviaPieces)
    }
    
    private static func extractFunctionBodyLines(from function: FunctionDeclSyntax) -> [String] {
        guard let body = function.body else {
            return ["{ }"]
        }
        
        // Extract the statements from the function body
        let statements = body.statements
        
        if statements.count == 1, let returnStmt = statements.first?.item.as(ReturnStmtSyntax.self) {
            // Single return statement - extract just the expression
            if let expression = returnStmt.expression {
                let expressionString = expression.description
                return preserveFormattingLines(expressionString)
            }
        } else if statements.count == 1 {
            // Single expression statement (implicit return)
            let statement = statements.first!.item
            let statementString = statement.description
            return preserveFormattingLines(statementString)
        } else {
            // Multiple statements - return the whole body
            let bodyContent = statements.map { stmt in
                stmt.description
            }.joined(separator: "\n")
            return preserveFormattingLines(bodyContent)
        }
        
        return ["{ }"]
    }
    
    private static func preserveFormattingLines(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        
        let trimmedLines = lines.drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .reversed()
            .drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .reversed()
        
        return Array(trimmedLines)
    }
    
    private static func getActualReturnTypeString(from function: FunctionDeclSyntax) -> String {
        guard let returnClause = function.signature.returnClause else {
            return "Void"
        }
        
        return returnClause.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func extractFunctionBody(from function: FunctionDeclSyntax) -> String {
        guard let body = function.body else {
            return "{ }"
        }
        
        // Extract the statements from the function body
        let statements = body.statements
        
        if statements.count == 1, let returnStmt = statements.first?.item.as(ReturnStmtSyntax.self) {
            // Single return statement - extract just the expression
            if let expression = returnStmt.expression {
                return expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if statements.count == 1 {
            // Single expression statement (implicit return)
            let statement = statements.first!.item
            return statement.description.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Multiple statements - return the whole body
            let bodyContent = statements.map { stmt in
                stmt.description.trimmingCharacters(in: .whitespacesAndNewlines)
            }.joined(separator: "\n")
            return bodyContent
        }
        
        return "{ }"
    }
    
    private static func generateValueCaseSwitch(for function: TrackedFunction) throws -> SwitchCaseSyntax {
        let functionCall = generateFunctionCall(for: function)
        let destinationInit = generateDestinationInit(for: function, functionCall: functionCall)
        
        if function.parameters.isEmpty {
            return SwitchCaseSyntax(
                "case .\(raw: function.name): return \(raw: destinationInit)"
            )
        } else {
            let paramExtraction = generateParameterExtraction(for: function)
            return SwitchCaseSyntax(
                "case .\(raw: function.name)\(raw: paramExtraction): return \(raw: destinationInit)"
            )
        }
    }
    
    private static func generateParameterExtraction(for function: TrackedFunction) -> String {
        if function.parameters.isEmpty {
            return ""
        }
        
        let params = function.parameters.map { param in
            return "let \(param.name)"
        }.joined(separator: ", ")
        
        return "(\(params))"
    }
    
    private static func generateFunctionCall(for function: TrackedFunction) -> String {
        if function.parameters.isEmpty {
            return "instance.\(function.name)()"
        }
        
        let params = function.parameters.map { param in
            if let label = param.label {
                return "\(label): \(param.name)"
            } else {
                return param.name
            }
        }.joined(separator: ", ")
        
        return "instance.\(function.name)(\(params))"
    }
    
    private static func generateDestinationInit(for function: TrackedFunction, functionCall: String) -> String {
        switch function.returnType {
        case .someView:
            return ".init(\(functionCall), meta: meta, parent: instance)"
        case .anyCoordinatable:
            return ".init({ [unowned instance] in \(functionCall) }, meta: meta, parent: instance)"
        case .coordinatableViewTuple, .viewViewTuple:
            return ".init({ [unowned instance] in \(functionCall) }, meta: meta, parent: instance)"
        case .void, .other:
            return ".init({ [unowned instance] in \(functionCall) }, meta: meta, parent: instance)"
        }
    }
}

// MARK: - Supporting Types

enum CoordinatableType {
    case flow, tab, root
}

enum ReturnTypeInfo {
    case void
    case someView
    case anyCoordinatable
    case coordinatableViewTuple
    case viewViewTuple
    case other
}

struct TrackedFunction {
    let name: String
    let parameters: [Parameter]
    let returnType: ReturnTypeInfo
    let originalFunction: FunctionDeclSyntax
    
    init(function: FunctionDeclSyntax, returnType: ReturnTypeInfo) throws {
        self.name = function.name.text
        self.returnType = returnType
        self.originalFunction = function
        self.parameters = try function.signature.parameterClause.parameters.map { param in
            try Parameter(from: param)
        }
    }
}

struct Parameter {
    let label: String?
    let name: String
    let type: String
    
    init(from param: FunctionParameterSyntax) throws {
        // Handle parameter labels
        if param.firstName.text != "_" {
            self.label = param.firstName.text
        } else {
            self.label = nil
        }
        
        // Handle parameter names
        if let secondName = param.secondName {
            self.name = secondName.text
        } else {
            self.name = param.firstName.text == "_" ? "value" : param.firstName.text
        }
        
        // Extract type and strip @escaping and other function-only attributes
        let typeString = param.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        self.type = Self.stripFunctionAttributes(from: typeString)
    }
    
    private static func stripFunctionAttributes(from typeString: String) -> String {
        var result = typeString
        
        result = result.replacingOccurrences(of: "@escaping ", with: "")
        result = result.replacingOccurrences(of: "@autoclosure ", with: "")
        
        result = result.replacingOccurrences(of: "  ", with: " ")
        
        return result.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Errors and Warnings

enum FlowMacroError: Error, CustomStringConvertible {
    case onlyApplicableToClass
    case mustConformToCoordinatable
    case invalidParameter
    case codeGenerationFailed
    
    var description: String {
        switch self {
        case .onlyApplicableToClass:
            return "@Flow can only be applied to classes"
        case .mustConformToCoordinatable:
            return "@Flow can only be applied to classes that conform to FlowCoordinatable, TabCoordinatable, or RootCoordinatable"
        case .invalidParameter:
            return "Invalid function parameter"
        case .codeGenerationFailed:
            return "Failed to generate extension code"
        }
    }
}

struct FlowMacroWarning: DiagnosticMessage {
    static let tupleIgnoredInNonTabCoordinatable = FlowMacroWarning(
        message: "Second view in tuple return type will be ignored in non-TabCoordinatable classes",
        severity: .warning
    )
    
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity
    
    init(message: String, severity: DiagnosticSeverity) {
        self.message = message
        self.severity = severity
        self.diagnosticID = MessageID(domain: "ZenMacros", id: message)
    }
}
