//
//  ObservableState.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

/// State를 KeyPath 기반 세밀한 관찰이 가능하도록 변환하는 매크로
///
/// 이 매크로는 Store에서 프로퍼티별 세밀한 관찰을 가능하게 하기 위해
/// ObservableStateProtocol 준수를 위한 메타데이터와 비교 함수를 자동 생성합니다.
///
/// ## 기능
///
/// - **KeyPath 추적**: 모든 저장 프로퍼티의 KeyPath를 자동으로 수집
/// - **변경 감지**: 프로퍼티별 변경 여부를 정확하게 판단
/// - **View 최적화**: 변경된 프로퍼티를 사용하는 View만 업데이트
///
/// ## 사용 예시
///
/// ```swift
/// struct CounterReducer: Reducer {
///     @ObservableState
///     struct State: Equatable {
///         var count: Int = 0
///         var isLoading: Bool = false
///         var numberFact: String? = nil
///     }
/// }
/// ```
///
/// ## 생성되는 코드 (개념적)
///
/// ```swift
/// extension CounterReducer.State: ObservableStateProtocol {
///     static var _$observableKeyPaths: [PartialKeyPath<Self>] {
///         [\Self.count, \Self.isLoading, \Self.numberFact]
///     }
///
///     static func hasChanged(
///         _ keyPath: PartialKeyPath<Self>,
///         from oldValue: Self,
///         to newValue: Self
///     ) -> Bool {
///         // 변경 감지 로직
///     }
/// }
/// ```
///
/// ## 주의사항
///
/// - Equatable을 준수해야 합니다 (변경 감지를 위해)
/// - 계산 프로퍼티는 무시됩니다
/// - Sendable을 준수하면 더 안전합니다
///
/// - SeeAlso: ``ObservableStateProtocol``, ``Store``
@attached(extension, conformances: ObservableStateProtocol, names: named(_$observableKeyPaths), named(hasChanged(_:from:to:)))
public macro ObservableState() = #externalMacro(
    module: "ReducerKitMacros",
    type: "ObservableStateMacro"
)
