//
//  ObservableStateProtocol.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

import Foundation

/// @ObservableState 매크로가 적용된 State가 준수해야 하는 프로토콜
///
/// 이 프로토콜은 KeyPath 기반의 세밀한 관찰을 위해
/// Store에서 필요한 메타데이터와 비교 함수를 정의합니다.
///
/// ## 목적
///
/// Store가 프로퍼티별 세밀한 관찰을 수행하기 위해 다음 정보가 필요합니다:
///
/// - 어떤 프로퍼티들이 관찰 가능한지 (KeyPath 목록)
/// - 특정 프로퍼티가 실제로 변경되었는지 (변경 감지)
///
/// 이 프로토콜이 이 두 가지 정보를 제공합니다.
///
/// ## 자동 구현
///
/// @ObservableState 매크로를 State에 적용하면 이 프로토콜이 자동으로 구현됩니다.
/// 직접 구현할 필요가 없습니다.
///
/// ```swift
/// @ObservableState
/// struct MyState: Equatable {
///     var count: Int = 0
/// }
/// // 자동으로 ObservableStateProtocol 준수
/// ```
///
/// - SeeAlso: ``ObservableState``, ``Store``
public protocol ObservableStateProtocol: Equatable, Sendable {

    /// State의 모든 관찰 가능한 프로퍼티의 KeyPath 목록
    ///
    /// @ObservableState 매크로가 자동으로 생성합니다.
    /// 모든 저장 프로퍼티의 KeyPath를 포함합니다.
    ///
    /// ## 예시
    ///
    /// ```swift
    /// @ObservableState
    /// struct CounterState: Equatable {
    ///     var count: Int
    ///     var isLoading: Bool
    /// }
    ///
    /// // 자동 생성:
    /// // _$observableKeyPaths = [\.count, \.isLoading]
    /// ```
    static var _$observableKeyPaths: [PartialKeyPath<Self>] { get }

    /// 특정 KeyPath의 값이 두 State 사이에서 변경되었는지 확인
    ///
    /// Store는 이 메서드를 통해 어떤 프로퍼티가 변경되었는지 파악하고,
    /// 해당 프로퍼티를 사용하는 View만 업데이트합니다.
    ///
    /// - Parameters:
    ///   - keyPath: 비교할 KeyPath
    ///   - oldValue: 이전 상태
    ///   - newValue: 새로운 상태
    /// - Returns: 값이 변경되었으면 true, 같으면 false
    ///
    /// ## 예시
    ///
    /// ```swift
    /// let old = CounterState(count: 0, isLoading: false)
    /// let new = CounterState(count: 1, isLoading: false)
    ///
    /// // count가 변경됨
    /// CounterState.hasChanged(\.count, from: old, to: new)  // true
    ///
    /// // isLoading은 변경 안 됨
    /// CounterState.hasChanged(\.isLoading, from: old, to: new)  // false
    /// ```
    static func hasChanged(
        _ keyPath: PartialKeyPath<Self>,
        from oldValue: Self,
        to newValue: Self
    ) -> Bool
}
