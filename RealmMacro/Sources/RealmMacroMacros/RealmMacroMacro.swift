import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingAttributesFor member: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
) throws -> [AttributeSyntax] {
    return []
    guard let property = member.as(VariableDeclSyntax.self), property.bindings.count == 1 else {
        return []
    }

    if let attributes = property.attributes {
        for attr in attributes {
            if case let .attribute(attr) = attr {
                if attr.attributeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == "Ignored" {
                    return []
                }
            }
        }
    }

    let binding = property.bindings.first!
    switch binding.accessor {
    case .none:
        break
    case .accessors(let node):
        for accessor in node.accessors {
            switch accessor.accessorKind.tokenKind {
            case .keyword(.get), .keyword(.set):
                return []
            default:
                break
            }
        }
        break
    case .getter:
        return []
    }

    return [
        AttributeSyntax(
            attributeName: SimpleTypeIdentifierSyntax(name: .identifier("Persisted"))
        )
        .with(\.leadingTrivia, [.newlines(1), .spaces(2)])
    ]
}

public struct RealmObjectMacro: MemberMacro, ConformanceMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingConformancesOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [(TypeSyntax, GenericWhereClauseSyntax?)] {
        return [(TypeSyntax("RealmSwift._RealmObjectSchemaDiscoverable"), nil)]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let declaration = declaration.as(ClassDeclSyntax.self) else { fatalError() }
        let className = declaration.identifier
        let properties = declaration.memberBlock.members.compactMap { (decl) -> (String, String, AttributeSyntax)? in
            guard let property = decl.decl.as(VariableDeclSyntax.self), property.bindings.count == 1 else {
                return nil
            }
            guard let attributes = property.attributes else { return nil }
            let persistedAttr = attributes.compactMap { attr in
                if case let .attribute(attr) = attr {
                    if attr.attributeName.as(SimpleTypeIdentifierSyntax.self)?.name.text == "Persisted" {
                        return attr
                    }
                }
                return nil
            }.first
            guard let persistedAttr else { return nil }

            let binding = property.bindings.first!
            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }
            guard let typeAnnotation = binding.typeAnnotation else { return nil }
            let name = identifier.identifier.text
            let type = typeAnnotation.type.trimmedDescription
            return (name, type, persistedAttr)
        }

        let rlmProperties = properties.map { (name, type, persistedAttr) in
            let expr = ExprSyntax("RLMProperty(name: \(literal: name), type: \(raw: type).self, keyPath: \\\(className).\(raw: name))")
            var functionCall = expr.as(FunctionCallExprSyntax.self)!

            if let argument = persistedAttr.argument, case let .argumentList(argList) = argument {
                var argumentList = Array(functionCall.argumentList)
                argumentList[argumentList.count - 1].trailingComma = ", "
                argumentList.append(contentsOf: argList)
                functionCall.argumentList = TupleExprElementListSyntax(argumentList)
            }
            return functionCall.as(ExprSyntax.self)!
        }
        return ["""

        static var _rlmProperties: [RLMProperty] = \(ArrayExprSyntax {
            for property in rlmProperties {
                ArrayElementSyntax(expression: property)
            }
            })
        """]
    }
}

@main
struct RealmMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RealmObjectMacro.self,
    ]
}
