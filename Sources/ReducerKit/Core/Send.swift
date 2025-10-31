//
//  Send.swift
//  ReducerKit
//
//  Created by 이정동 on 10/3/25.
//

import Foundation

/// Effect 내부에서 새로운 Action을 전송하기 위한 래퍼 구조체
///
/// Send 객체는 비동기 작업에서 Store로 Action을 다시 전달하는 인터페이스를 제공합니다.
/// callAsFunction을 구현하여 함수처럼 호출할 수 있습니다: `await send(.action)`
///
/// ## 역할
///
/// Effect 내의 비동기 작업(네트워크 요청, 타이머 등)이 완료되었을 때,
/// 결과를 새로운 Action으로 감싸서 Store에 다시 전달합니다.
/// 이를 통해 Reducer가 다시 호출되어 상태를 업데이트할 수 있습니다.
///
/// ## 사용 흐름
///
/// 1. Reducer가 Effect를 반환
/// 2. Store의 handleEffect에서 비동기 작업 실행
/// 3. Send를 통해 Action 전송
/// 4. Store가 새로운 Action을 받아서 다시 reduce 호출
/// 5. 상태 업데이트 및 View 리드로우
///
/// ## 사용 예시
///
/// ```swift
/// case .fetchUser(let id):
///     state.isLoading = true
///     return .run { send in
///         do {
///             let user = try await api.fetchUser(id: id)
///             await send(.userLoaded(.success(user)))
///         } catch {
///             await send(.userLoaded(.failure(error)))
///         }
///     }
/// ```
///
/// - SeeAlso: ``Effect``, ``Reducer``, ``Store``
public struct Send<Action: Sendable>: Sendable {
    /// 실제 Action을 전달하는 클로저
    let send: @Sendable (Action) async -> Void

    /// Send 객체 초기화
    /// - Parameter send: Action을 처리할 비동기 클로저
    public init(_ send: @escaping @Sendable (Action) async -> Void) {
        self.send = send
    }

    /// Send 객체를 함수처럼 호출할 수 있게 합니다.
    ///
    /// callAsFunction을 구현하여 `await send(.action)` 형태로 호출 가능합니다.
    ///
    /// - Parameter action: 전송할 Action
    public func callAsFunction(_ action: Action) async {
        await send(action)
    }
}
