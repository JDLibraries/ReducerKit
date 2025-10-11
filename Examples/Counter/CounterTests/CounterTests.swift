//
//  CounterTests.swift
//  CounterTests
//
//  Created by 이정동 on 10/4/25.
//

import Testing
@testable import Counter

struct CounterTests {

    // MARK: - Test Helpers

    let reducer = CounterReducer()

    // MARK: - Increment Tests

    @Test("증가 버튼을 누르면 카운트가 1 증가한다")
    func testIncrement() {
        var state = CounterReducer.State(count: 0)
        _ = reducer.reduce(into: &state, action: .increment)

        #expect(state.count == 1)
    }

    @Test("증가 버튼을 여러 번 누르면 카운트가 계속 증가한다")
    func testMultipleIncrements() {
        var state = CounterReducer.State(count: 0)

        _ = reducer.reduce(into: &state, action: .increment)
        _ = reducer.reduce(into: &state, action: .increment)
        _ = reducer.reduce(into: &state, action: .increment)

        #expect(state.count == 3)
    }

    // MARK: - Decrement Tests

    @Test("감소 버튼을 누르면 카운트가 1 감소한다")
    func testDecrement() {
        var state = CounterReducer.State(count: 5)
        _ = reducer.reduce(into: &state, action: .decrement)

        #expect(state.count == 4)
    }

    @Test("감소 버튼을 누르면 음수가 될 수 있다")
    func testDecrementToNegative() {
        var state = CounterReducer.State(count: 0)
        _ = reducer.reduce(into: &state, action: .decrement)

        #expect(state.count == -1)
    }

    // MARK: - Number Fact Tests

    @Test("숫자 팩트 버튼을 누르면 로딩 상태가 true가 되고 기존 팩트가 제거된다")
    func testNumberFactButtonTapped() {
        var state = CounterReducer.State(
            count: 42,
            isLoading: false,
            numberFact: "Old fact"
        )
        _ = reducer.reduce(into: &state, action: .numberFactButtonTapped)

        #expect(state.isLoading == true)
        #expect(state.numberFact == nil)
    }

    @Test("숫자 팩트 응답을 받으면 로딩이 끝나고 팩트가 저장된다")
    func testNumberFactResponse() {
        var state = CounterReducer.State(
            count: 42,
            isLoading: true,
            numberFact: nil
        )
        let fact = "42 is the answer to life, the universe, and everything"
        _ = reducer.reduce(into: &state, action: .numberFactResponse(fact))

        #expect(state.isLoading == false)
        #expect(state.numberFact == fact)
    }

    @Test("숫자 팩트 로딩 중에도 증가/감소 버튼은 작동한다")
    func testIncrementWhileLoading() {
        var state = CounterReducer.State(
            count: 5,
            isLoading: true,
            numberFact: nil
        )
        _ = reducer.reduce(into: &state, action: .increment)

        #expect(state.count == 6)
        #expect(state.isLoading == true) // 로딩 상태는 유지
    }

    // MARK: - State Initialization Tests

    @Test("초기 상태가 올바르게 설정된다")
    func testInitialState() {
        let state = CounterReducer.State()

        #expect(state.count == 0)
        #expect(state.isLoading == false)
        #expect(state.numberFact == nil)
    }

    // MARK: - Integration Tests

    @Test("전체 플로우: 증가 → 팩트 요청 → 응답")
    func testCompleteFlow() {
        var state = CounterReducer.State(count: 0)

        // 1. 증가
        _ = reducer.reduce(into: &state, action: .increment)
        #expect(state.count == 1)

        // 2. 팩트 요청
        _ = reducer.reduce(into: &state, action: .numberFactButtonTapped)
        #expect(state.isLoading == true)
        #expect(state.numberFact == nil)

        // 3. 팩트 응답
        let fact = "1 is the loneliest number"
        _ = reducer.reduce(into: &state, action: .numberFactResponse(fact))
        #expect(state.isLoading == false)
        #expect(state.numberFact == fact)
        #expect(state.count == 1) // 카운트는 변하지 않음
    }
}
