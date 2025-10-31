//
//  Store.swift
//  ReducerKit
//
//  Created by ReducerKit on 10/11/25.
//

import Foundation

/// KeyPath 기반 세밀한 관찰을 지원하는 상태 관리자
///
/// Store는 ReducerKit의 핵심 타입으로, 애플리케이션의 상태를 저장하고 관리합니다.
/// @ObservableState가 적용된 State를 사용하면 프로퍼티별 변경을 추적하여
/// 필요한 View만 업데이트합니다.
///
/// ## 주요 기능
///
/// - **상태 저장**: 애플리케이션의 현재 상태를 보관합니다.
/// - **Action 처리**: View에서 전달받은 Action을 Reducer에 전달합니다.
/// - **Effect 실행**: Reducer가 반환한 부수 효과를 실행합니다.
/// - **세밀한 관찰**: KeyPath 기반으로 변경된 프로퍼티만 View를 업데이트합니다.
///
/// ## 사용 예시
///
/// ```swift
/// struct CounterReducer: Reducer {
///     @ObservableState
///     struct State: Equatable {
///         var count: Int = 0
///         var isLoading: Bool = false
///     }
///
///     enum Action: Sendable {
///         case increment
///     }
///
///     func reduce(into state: inout State, action: Action) -> Effect<Action> {
///         switch action {
///         case .increment:
///             state.count += 1
///             return .none
///         }
///     }
/// }
///
/// struct ContentView: View {
///     @State private var store = Store(
///         initialState: CounterReducer.State(),
///         reducer: CounterReducer()
///     )
///
///     var body: some View {
///         Text("\\(store.count)")
///         Button("+") {
///             store.send(.increment)
///         }
///     }
/// }
/// ```
///
/// ## View에서의 접근
///
/// - **올바른 방법**: `store.count` (dynamicMemberLookup 사용)
/// - **피해야 할 방법**: `store.state.count` (스냅샷으로 접근 → 업데이트 감지 안 됨)
///
/// - SeeAlso: ``Reducer``, ``Effect``, ``Send``
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
            observableVersions[AnyHashable(keyPath)] = ObservableVersion()
        }
    }

    /// 전체 State 읽기 (읽기 전용)
    ///
    /// **주의**: View에서는 `@dynamicMemberLookup`을 통해 개별 프로퍼티에 접근하세요.
    ///
    /// 사용 사례:
    /// - 전체 State를 함수에 전달
    /// - 디버깅/로깅
    /// - State 스냅샷 저장
    public var state: State {
        get { _state }
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
            // Effect 내부에서 새로운 Action을 전송하기 위한 Send 객체 생성
            let send = Send<Action> { [weak self] action in
                // Send를 통해 전달된 Action을 Store에서 처리
                await self?.send(action)
            }

            // 비동기 작업을 백그라운드 Task에서 실행 (메인 스레드 분리)
            Task.detached {
                await operation(send)
            }
        }
    }
}
