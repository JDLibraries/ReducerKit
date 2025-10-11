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
/// State의 메타데이터와 비교 함수를 제공합니다.
public protocol ObservableStateProtocol: Equatable, Sendable {

    /// State의 모든 KeyPath 목록
    ///
    /// @ObservableState 매크로가 자동으로 생성합니다.
    static var _$observableKeyPaths: [PartialKeyPath<Self>] { get }

    /// 특정 KeyPath의 값이 변경되었는지 확인
    ///
    /// - Parameters:
    ///   - keyPath: 비교할 KeyPath
    ///   - oldValue: 이전 상태
    ///   - newValue: 새로운 상태
    /// - Returns: 값이 변경되었으면 true
    static func hasChanged(
        _ keyPath: PartialKeyPath<Self>,
        from oldValue: Self,
        to newValue: Self
    ) -> Bool
}
