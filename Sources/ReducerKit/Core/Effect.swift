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
///
/// ## 개요
///
/// Effect는 Reducer의 상태 변화 로직과 부수 효과(네트워크 요청, 파일 I/O 등)를 명확히 분리합니다.
/// 이를 통해 Reducer는 순수 함수로 유지되고, 부수 효과는 Store에서 관리됩니다.
///
/// ## 종류
///
/// - **none**: 부수 효과가 없음
/// - **run**: 비동기 작업 수행
///
/// ## 사용 예시
///
/// ```swift
/// func reduce(into state: inout State, action: Action) -> Effect<Action> {
///     switch action {
///     case .increment:
///         state.count += 1
///         return .none  // 부수 효과 없음
///
///     case .fetchData:
///         state.isLoading = true
///         return .run { send in
///             do {
///                 let data = try await api.fetch()
///                 await send(.dataLoaded(.success(data)))
///             } catch {
///                 await send(.dataLoaded(.failure(error)))
///             }
///         }
///     }
/// }
/// ```
///
/// ## 에러 처리
///
/// Effect 내에서 발생한 에러는 Result 타입으로 감싸서 새로운 Action으로 전송하세요.
///
/// - SeeAlso: ``Reducer``, ``Send``
public enum Effect<Action: Sendable>: Sendable {

    /// 추가적인 작업을 실행하지 않음
    ///
    /// 상태만 변경하고 부수 효과가 없을 때 사용합니다.
    case none

    /// 비동기 작업을 실행하고, Send 객체를 통해 새로운 Action을 전달합니다.
    ///
    /// ## 실행 원리
    ///
    /// 1. Effect가 반환되면 Store의 handleEffect에서 감지합니다.
    /// 2. Task.detached로 백그라운드에서 비동기 작업을 실행합니다.
    /// 3. 작업 중에 Send를 통해 새로운 Action을 보낼 수 있습니다.
    /// 4. 보내진 Action은 다시 reduce 메서드로 전달되어 상태를 업데이트합니다.
    ///
    /// - Parameter operation: 비동기 작업을 수행하는 클로저
    ///   - send: 작업 중이나 완료 후 새로운 Action을 보내기 위한 Send 객체
    ///
    /// ## 사용 예시
    ///
    /// ```swift
    /// case .fetchUser:
    ///     state.isLoading = true
    ///     return .run { [userId = state.userId] send in
    ///         let user = await api.fetchUser(id: userId)
    ///         await send(.userLoaded(user))
    ///     }
    /// ```
    case run(@Sendable (_ send: Send<Action>) async -> Void)
}


