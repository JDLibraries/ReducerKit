//
//  Reducer.swift
//  ReducerKit
//
//  Created by 이정동 on 10/3/25.
//

import Foundation

/// 액션에 따른 상태 변화 로직을 정의하기 위한 프로토콜
///
/// Reducer는 순수 함수로, 현재 상태와 액션을 받아 새로운 상태로 변경하고
/// 필요한 부수 효과(Effect)를 반환합니다.
///
/// ## 주요 특징
///
/// - **순수 함수**: 외부 상태를 변경하지 않고 새로운 상태만 반환합니다.
/// - **결정적**: 같은 입력에 대해 항상 같은 출력을 합니다.
/// - **테스트 가능**: 상태 변화를 독립적으로 테스트할 수 있습니다.
/// - **동시성 안전**: Sendable을 준수하여 concurrency 환경에서 안전합니다.
///
/// ## 사용 패턴
///
/// ```swift
/// struct MyReducer: Reducer {
///
///     @ObservableState
///     struct State: Equatable {
///         var count: Int = 0
///         var isLoading: Bool = false
///     }
///
///     enum Action: Sendable {
///         case increment
///         case fetchData
///         case dataLoaded(Data)
///     }
///
///     func reduce(into state: inout State, action: Action) -> Effect<Action> {
///         switch action {
///         case .increment:
///             state.count += 1
///             return .none
///
///         case .fetchData:
///             state.isLoading = true
///             return .run { send in
///                 let data = await fetch()
///                 await send(.dataLoaded(data))
///             }
///         }
///     }
/// }
/// ```
///
/// - SeeAlso: ``Effect``, ``Store``, ``ObservableState``
public protocol Reducer: Sendable {
    /// View에 표시될 데이터를 정의
    ///
    /// Equatable을 준수하여 변경 감지를 효율적으로 수행할 수 있습니다.
    /// @ObservableState 매크로를 적용하면 프로퍼티별 관찰이 가능합니다.
    associatedtype State: Equatable

    /// View에서 발생할 수 있는 동작을 정의
    ///
    /// Sendable을 준수하여 concurrency 환경에서 안전하게 사용할 수 있습니다.
    /// Enum으로 정의하는 것을 권장합니다.
    associatedtype Action: Sendable

    /// 전달받은 액션에 따라 기존 상태를 새로운 상태로 변경합니다.
    ///
    /// - Parameters:
    ///   - state: 변경할 현재 상태 (inout으로 직접 수정)
    ///   - action: 처리할 액션
    /// - Returns: 실행할 부수 효과(Effect). 부수 효과가 없으면 .none 반환
    ///
    /// 사용 예시:
    /// ```swift
    /// func reduce(into state: inout State, action: Action) -> Effect<Action> {
    ///     switch action {
    ///     case .increment:
    ///         state.count += 1
    ///         return .none
    ///     case .fetchData:
    ///         state.isLoading = true
    ///         return .run { send in
    ///             let data = await apiClient.fetch()
    ///             await send(.dataLoaded(data))
    ///         }
    ///     }
    /// }
    /// ```
    func reduce(into state: inout State, action: Action) -> Effect<Action>
}
