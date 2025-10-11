//
//  Store.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

import Foundation

/// KeyPath별 버전을 개별적으로 관찰 가능하게 만드는 래퍼
@Observable
private final class ObservableVersion {
    var value: Int = 0
}

/// KeyPath 기반 세밀한 관찰을 지원하는 Store
///
/// @ObservableState가 적용된 State를 사용하면
/// 프로퍼티별 변경을 추적하여 필요한 View만 업데이트합니다.
///
/// 사용 예시:
/// ```swift
/// @ObservableState
/// struct CounterState: Equatable {
///     var count: Int = 0
///     var isLoading: Bool = false
/// }
///
/// let store = Store(
///     initialState: CounterState(),
///     reducer: CounterReducer()
/// )
/// ```
@MainActor @Observable
@dynamicMemberLookup
public final class Store<R: Reducer> where R.State: ObservableStateProtocol {

    public typealias State = R.State
    public typealias Action = R.Action

    /// 실제 상태 저장 (관찰에서 제외)
    @ObservationIgnored
    private var _state: State

    /// Reducer의 reduce 메서드
    @ObservationIgnored
    private let reduce: (inout State, Action) -> Effect<Action>

    /// KeyPath별 버전 관리 저장소 (관찰하지 않음)
    ///
    /// 이 Dictionary 자체는 관찰하지 않습니다.
    /// 대신 각 KeyPath별 computed property를 통해 개별 버전을 노출합니다.
    @ObservationIgnored
    private var _keyPathVersions: [PartialKeyPath<State>: Int] = [:]

    /// KeyPath별 Observable 버전 저장
    ///
    /// 각 KeyPath를 개별 Observable 프로퍼티로 노출하기 위한 저장소
    private var observableVersions: [AnyHashable: ObservableVersion] = [:]

    /// Store 초기화
    /// - Parameters:
    ///   - initialState: 초기 상태값
    ///   - reducer: 상태 변화 로직을 정의한 Reducer
    public init(initialState: State, reducer: R) {
        self._state = initialState
        self.reduce = reducer.reduce(into:action:)

        // 모든 KeyPath의 초기 버전 설정
        for keyPath in State._$observableKeyPaths {
            _keyPathVersions[keyPath] = 0
            observableVersions[AnyHashable(keyPath)] = ObservableVersion()
        }
    }

    /// 전체 state 접근 (호환성을 위해 제공)
    public var state: State {
        get {
            // 모든 KeyPath의 Observable 버전을 읽어서 전체 관찰 등록
            for keyPath in State._$observableKeyPaths {
                if let version = observableVersions[AnyHashable(keyPath)] {
                    _ = version.value
                }
            }
            return _state
        }
    }

    /// dynamicMemberLookup을 통한 개별 프로퍼티 접근 (핵심!)
    ///
    /// 사용 예시:
    /// ```swift
    /// Text("\(store.count)")  // store.state.count 대신
    /// ```
    ///
    /// 이렇게 하면 count 프로퍼티만 관찰하므로
    /// count가 변경될 때만 해당 View가 업데이트됩니다.
    public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
        // 이 KeyPath의 ObservableVersion.value를 읽음 → @Observable이 개별 관찰 등록
        if let version = observableVersions[AnyHashable(keyPath)] {
            _ = version.value
        }
        return _state[keyPath: keyPath]
    }

    /// View로부터 Action을 전달받아 상태를 업데이트합니다.
    ///
    /// 실행 흐름:
    /// 1. Reducer의 reduce 메서드를 호출하여 state를 업데이트
    /// 2. 변경된 KeyPath들의 버전을 증가시켜 해당 프로퍼티를 관찰하는 View만 업데이트
    /// 3. reduce가 반환한 Effect를 handleEffect로 전달
    ///
    /// - Parameter action: 처리할 Action
    public func send(_ action: Action) {
        let oldState = _state
        let effect = reduce(&_state, action)

        // 변경된 KeyPath만 버전 증가
        updateVersions(from: oldState, to: _state)

        handleEffect(effect)
    }

    /// 변경된 KeyPath의 버전을 업데이트
    ///
    /// - Parameters:
    ///   - oldState: 이전 상태
    ///   - newState: 새로운 상태
    private func updateVersions(from oldState: State, to newState: State) {
        for keyPath in State._$observableKeyPaths {
            // State의 hasChanged 메서드로 변경 확인
            if State.hasChanged(keyPath, from: oldState, to: newState) {
                // ObservableVersion.value 증가 → 해당 KeyPath를 관찰하는 View만 업데이트
                if let version = observableVersions[AnyHashable(keyPath)] {
                    version.value += 1
                }
            }
        }
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
            let send = Send<Action> { [weak self] action in
                await self?.send(action)
            }

            Task.detached {
                await operation(send)
            }
        }
    }
}
