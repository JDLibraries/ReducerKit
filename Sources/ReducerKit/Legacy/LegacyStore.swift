//
//  LegacyStore.swift
//  ReducerKit
//
//  Created by 이정동 on 10/3/25.
//

import Foundation

/// Reducer를 실행하고 UI를 업데이트하는 상태 관리자
///
/// Store는 단방향 데이터 플로우를 구현합니다:
/// 1. View에서 Action을 보냄 (`send`)
/// 2. Reducer가 State를 업데이트하고 Effect를 반환
/// 3. Effect가 있다면 비동기 작업을 실행하고, 완료 시 새로운 Action을 다시 보냄
///
/// @MainActor로 격리되어 UI 업데이트가 항상 메인 스레드에서 실행됩니다.
@available(*, deprecated, renamed: "Store", message: "Use Store with @ObservableState instead. This type will be removed in 2.0.0")
@MainActor @Observable
public final class LegacyStore<R: Reducer> {

    public typealias State = R.State
    public typealias Action = R.Action

    /// 현재 상태 (읽기 전용으로 외부 노출)
    private(set) public var state: State

    /// Reducer의 reduce 메서드를 클로저로 저장
    private let reduce: (inout State, Action) -> Effect<Action>

    /// Store 초기화
    /// - Parameters:
    ///   - initialState: 초기 상태값
    ///   - reducer: 상태 변화 로직을 정의한 Reducer
    public init(initialState: State, reducer: R) {
        self.state = initialState
        self.reduce = reducer.reduce(into:action:)
    }

    /// View로부터 Action을 전달받아 상태를 업데이트합니다.
    ///
    /// 실행 흐름:
    /// 1. Reducer의 reduce 메서드를 호출하여 state를 업데이트
    /// 2. reduce가 반환한 Effect를 handleEffect로 전달
    /// 3. Effect가 .run인 경우 비동기 작업 실행
    ///
    /// - Parameter action: 처리할 Action
    public func send(_ action: Action) {
        let effect = reduce(&state, action)
        handleEffect(effect)
    }

    /// Reducer가 반환한 Effect를 처리합니다.
    ///
    /// - `.none`: 아무 작업도 하지 않음
    /// - `.run`: 비동기 작업을 백그라운드에서 실행
    ///
    /// - Parameter effect: 처리할 Effect
    private func handleEffect(_ effect: Effect<Action>) {
        switch effect {
        case .none:
            break
        case let .run(operation):
            // 1. Send 객체 생성
            // 비동기 작업(operation) 내부에서 새로운 Action을 보낼 수 있는 인터페이스를 제공합니다.
            // weak self를 사용하여 순환 참조를 방지합니다.
            let send = Send<Action> { [weak self] action in
                await self?.send(action)  // 메인 액터로 돌아와서 send 호출
            }

            // 2. Task.detached로 비동기 작업 실행
            // - operation: Reducer에서 정의한 비동기 작업 클로저
            //   예: { send in
            //          let data = await apiClient.fetch()
            //          await send(.dataLoaded(data))
            //       }
            // - Task.detached 사용 이유:
            //   · 메인 액터와 격리된 백그라운드 스레드에서 실행
            //   · 무거운 비동기 작업(네트워크, DB 등)이 메인 스레드를 블로킹하지 않음
            //   · operation 내부에서 await send()를 호출하면 자동으로 메인 액터로 전환됨
            // - 실행 흐름:
            //   1) operation이 백그라운드에서 비동기 작업 수행
            //   2) 작업 완료 후 await send(action) 호출
            //   3) Send 내부의 클로저가 메인 액터에서 self?.send(action) 실행
            //   4) Store.send()가 다시 호출되어 순환 구조 형성
            Task.detached {
                await operation(send)
            }
        }
    }
}
