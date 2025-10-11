//
//  ObservableState.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

/// State struct를 KeyPath 기반 세밀한 관찰이 가능하도록 변환하는 매크로
///
/// 이 매크로는 State의 각 프로퍼티를 개별적으로 관찰할 수 있도록
/// 메타데이터와 비교 함수를 자동 생성합니다.
///
/// 사용 예시:
/// ```swift
/// @ObservableState
/// struct CounterState: Equatable {
///     var count: Int = 0
///     var isLoading: Bool = false
///     var numberFact: String? = nil
/// }
/// ```
///
/// 생성되는 코드:
/// ```swift
/// extension CounterState: ObservableStateProtocol {
///     static var _$observableKeyPaths: [PartialKeyPath<Self>] {
///         [\Self.count, \Self.isLoading, \Self.numberFact]
///     }
///
///     static func hasChanged(
///         _ keyPath: PartialKeyPath<Self>,
///         from oldValue: Self,
///         to newValue: Self
///     ) -> Bool {
///         switch keyPath {
///         case \Self.count:
///             return oldValue.count != newValue.count
///         case \Self.isLoading:
///             return oldValue.isLoading != newValue.isLoading
///         case \Self.numberFact:
///             return oldValue.numberFact != newValue.numberFact
///         default:
///             return false
///         }
///     }
/// }
/// ```
@attached(extension, conformances: ObservableStateProtocol, names: named(_$observableKeyPaths), named(hasChanged(_:from:to:)))
public macro ObservableState() = #externalMacro(
    module: "ReducerKitMacros",
    type: "ObservableStateMacro"
)
