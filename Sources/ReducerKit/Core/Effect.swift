//
//  Effect.swift
//  ReducerKit
//
//  Created by 이정동 on 10/3/25.
//

import Foundation

/// Reducer가 처리한 결과로 발생시킬 수 있는 부수 효과(Side Effect)
///
/// Reducer는 순수 함수로 상태만 변경하고, 비동기 작업이나 외부 의존성이 필요한 작업은
/// Effect로 반환하여 Store가 처리하도록 합니다.
public enum Effect<Action: Sendable>: Sendable {

    /// 추가적인 작업을 실행하지 않음
    ///
    /// 상태만 변경하고 부수 효과가 없을 때 사용합니다.
    case none

    /// 비동기 작업을 실행하고, Send 객체를 통해 새로운 Action을 전달합니다.
    ///
    /// - Parameter operation: 비동기 작업을 수행하는 클로저
    ///   - send: 작업 완료 후 새로운 Action을 보내기 위한 Send 객체
    ///
    /// 사용 예시:
    /// ```swift
    /// case .fetchData:
    ///     return .run { send in
    ///         let data = await apiClient.fetch()
    ///         await send(.dataLoaded(data))
    ///     }
    /// ```
    case run(@Sendable (_ send: Send<Action>) async -> Void)
}


