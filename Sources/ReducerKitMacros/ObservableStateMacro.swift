//
//  ObservableStateMacro.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// @ObservableState 매크로 구현
///
/// State struct에 ObservableStateProtocol 준수 코드를 자동 생성합니다.
public struct ObservableStateMacro: ExtensionMacro {

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        // 1. struct인지 확인
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.notAStruct
        }

        // 2. 저장 프로퍼티들 찾기
        let properties = structDecl.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .filter { $0.isStoredProperty }

        guard !properties.isEmpty else {
            throw MacroError.noStoredProperties
        }

        // 3. KeyPath 배열 생성
        let keyPathsArray = properties.map { property in
            let name = property.bindings.first!.pattern
            return #"\Self.\#(name)"#
        }.joined(separator: ", ")

        // 4. hasChanged switch cases 생성
        let switchCases = properties.map { property in
            let name = property.bindings.first!.pattern
            return """
                    case \\Self.\(name):
                        return oldValue.\(name) != newValue.\(name)
            """
        }.joined(separator: "\n")

        // 5. Extension 생성
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): ObservableStateProtocol {
                public static var _$observableKeyPaths: [PartialKeyPath<Self>] {
                    [\(raw: keyPathsArray)]
                }

                public static func hasChanged(
                    _ keyPath: PartialKeyPath<Self>,
                    from oldValue: Self,
                    to newValue: Self
                ) -> Bool {
                    switch keyPath {
                    \(raw: switchCases)
                    default:
                        return false
                    }
                }
            }
            """

        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            throw MacroError.invalidExtension
        }

        return [ext]
    }
}

// MARK: - Helper Extensions

extension VariableDeclSyntax {
    /// 저장 프로퍼티인지 확인
    var isStoredProperty: Bool {
        // getter/setter가 없고, willSet/didSet도 없으면 저장 프로퍼티
        if bindings.first?.accessorBlock != nil {
            return false
        }
        // static이나 computed가 아니면 저장 프로퍼티
        return modifiers.allSatisfy { modifier in
            !["static", "class"].contains(modifier.name.text)
        }
    }
}

// MARK: - Error Types

enum MacroError: Error, CustomStringConvertible {
    case notAStruct
    case noStoredProperties
    case invalidExtension

    var description: String {
        switch self {
        case .notAStruct:
            return "@ObservableState can only be applied to structs"
        case .noStoredProperties:
            return "@ObservableState requires at least one stored property"
        case .invalidExtension:
            return "Failed to generate extension code"
        }
    }
}
