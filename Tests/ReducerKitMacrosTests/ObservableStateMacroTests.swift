//
//  ObservableStateMacroTests.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(ReducerKitMacros)
import ReducerKitMacros

final class ObservableStateMacroTests: XCTestCase {

    let macros = ["ObservableState": ObservableStateMacro.self]

    func testObservableStateMacro() {
        assertMacroExpansion(
            """
            @ObservableState
            struct CounterState: Equatable {
                var count: Int = 0
                var isLoading: Bool = false
            }
            """,
            expandedSource: """
            struct CounterState: Equatable {
                var count: Int = 0
                var isLoading: Bool = false
            }

            extension CounterState: ObservableStateProtocol {
                public static var _$observableKeyPaths: [PartialKeyPath<Self>] {
                    [\\Self.count, \\Self.isLoading]
                }

                public static func hasChanged(
                    _ keyPath: PartialKeyPath<Self>,
                    from oldValue: Self,
                    to newValue: Self
                ) -> Bool {
                    switch keyPath {
                            case \\Self.count:
                        return oldValue.count != newValue.count
                    case \\Self.isLoading:
                        return oldValue.isLoading != newValue.isLoading
                    default:
                        return false
                    }
                }
            }
            """,
            macros: macros
        )
    }
}
#endif
