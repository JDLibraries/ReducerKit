//
//  ReducerKitMacrosPlugin.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ReducerKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ObservableStateMacro.self,
    ]
}
