//
//  CounterReducer.swift
//  Counter
//
//  Created by ReducerKit on 10/3/25.
//

import Foundation
import ReducerKit

/// Counter 기능을 위한 Reducer
struct CounterReducer: Reducer {

    // MARK: - State

    /// Counter 화면의 상태
    struct State: Equatable {
        /// 현재 카운트 값
        var count: Int = 0
        /// 로딩 중 여부
        var isLoading: Bool = false
        /// 숫자에 대한 재미있는 사실
        var numberFact: String?
    }

    // MARK: - Action

    /// Counter 화면에서 발생할 수 있는 액션
    enum Action: Sendable {
        /// 증가 버튼 탭
        case increment
        /// 감소 버튼 탭
        case decrement
        /// 숫자 팩트 요청 버튼 탭
        case numberFactButtonTapped
        /// 숫자 팩트 응답 받음
        case numberFactResponse(String)
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .decrement:
            state.count -= 1
            return .none

        case .numberFactButtonTapped:
            state.isLoading = true
            state.numberFact = nil
            // 현재 count 값을 캡처하여 네트워크 요청
            return .run { [count = state.count] send in
                do {
                    let (data, _) = try await URLSession.shared.data(
                        from: URL(string: "http://numbersapi.com/\(count)/trivia")!
                    )
                    let fact = String(decoding: data, as: UTF8.self)
                    await send(.numberFactResponse(fact))
                } catch {
                    await send(.numberFactResponse("Failed to load fact"))
                }
            }

        case let .numberFactResponse(fact):
            state.isLoading = false
            state.numberFact = fact
            return .none
        }
    }
}
