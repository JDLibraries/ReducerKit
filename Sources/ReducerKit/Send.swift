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
/// 사용 예시:
/// ```swift
/// return .run { send in
///     let data = await fetchData()
///     await send(.dataLoaded(data))  // Store의 send(_:) 메서드가 호출됨
/// }
/// ```
public struct Send<Action: Sendable>: Sendable {
    /// 실제 Action을 전달하는 클로저
    let send: @Sendable (Action) async -> Void

    /// Send 객체 초기화
    /// - Parameter send: Action을 처리할 비동기 클로저
    public init(_ send: @escaping @Sendable (Action) async -> Void) {
        self.send = send
    }

    /// Send 객체를 함수처럼 호출할 수 있게 합니다.
    /// - Parameter action: 전송할 Action
    public func callAsFunction(_ action: Action) async {
        await send(action)
    }
}
