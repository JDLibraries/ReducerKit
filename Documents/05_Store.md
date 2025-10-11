# Store 타입

## 개요

`Store`는 ReducerKit의 핵심 타입으로, 다음 역할을 수행합니다:

1. **State 저장 및 관리**: 앱의 현재 상태를 보관
2. **Action 처리**: View에서 전달받은 Action을 Reducer에 전달
3. **Effect 실행**: Reducer가 반환한 부수 효과를 실행
4. **세밀한 관찰**: KeyPath 기반으로 변경된 프로퍼티만 View 업데이트

## 전체 코드 구조

```swift
@MainActor @Observable
@dynamicMemberLookup
public final class Store<R: Reducer> where R.State: ObservableStateProtocol {
    // 저장 프로퍼티
    @ObservationIgnored private var _state: State
    @ObservationIgnored private let reduce: (inout State, Action) -> Effect<Action>
    @ObservationIgnored private var _keyPathVersions: [PartialKeyPath<State>: Int]
    private var observableVersions: [AnyHashable: ObservableVersion]

    // 공개 API
    public init(initialState: State, reducer: R)
    public var state: State { get }
    public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value
    public func send(_ action: Action)
}
```

## 코드 상세 분석

### 1. 클래스 선언

```swift
@MainActor @Observable
@dynamicMemberLookup
public final class Store<R: Reducer> where R.State: ObservableStateProtocol {
```

이 한 줄에 많은 개념이 담겨있습니다.

#### `@MainActor`

모든 메서드와 프로퍼티가 메인 스레드에서만 실행됩니다.

```swift
@MainActor
class Store {
    // 이 클래스의 모든 것이 메인 스레드에서 실행됨
    func send(_ action: Action) {
        // UI 업데이트가 필요하므로 메인 스레드 보장
    }
}

// 사용 예시
Task {
    // 백그라운드 스레드에서 실행
    let data = await fetchData()

    // Store.send는 @MainActor이므로 자동으로 메인 스레드로 전환
    await store.send(.dataLoaded(data))
}
```

**왜 필요한가?**
- SwiftUI View 업데이트는 반드시 메인 스레드에서 실행되어야 함
- Store가 State를 변경하면 View가 업데이트되므로 @MainActor 필수

#### `@Observable`

Swift 5.9의 새로운 관찰 시스템입니다.

```swift
// 옛날 방식
class OldStore: ObservableObject {
    @Published var count: Int = 0  // 각 프로퍼티에 @Published 필요
}

// 새로운 방식
@Observable
class NewStore {
    var count: Int = 0  // 자동으로 관찰 가능
}
```

**@Observable의 장점**:
1. 프로퍼티별 세밀한 관찰 가능
2. `@Published` 불필요
3. 더 나은 성능

**내부 동작**:
```swift
@Observable
class Store {
    var count: Int = 0
}

// 매크로가 자동 생성하는 코드 (개념적으로)
class Store {
    private var _count: Int = 0

    var count: Int {
        get {
            // 현재 View를 이 프로퍼티의 관찰자로 등록
            access(keyPath: \.count)
            return _count
        }
        set {
            // 관찰자들에게 변경 알림
            withMutation(keyPath: \.count) {
                _count = newValue
            }
        }
    }
}
```

#### `@dynamicMemberLookup`

존재하지 않는 프로퍼티 접근을 가로채서 처리합니다.

```swift
@dynamicMemberLookup
struct Wrapper {
    var value: Int

    subscript<T>(dynamicMember keyPath: KeyPath<Int, T>) -> T {
        value[keyPath: keyPath]
    }
}

let wrapper = Wrapper(value: 42)
print(wrapper.bitWidth)  // Int의 bitWidth 프로퍼티에 접근
// 실제로는: wrapper.subscript(dynamicMember: \.bitWidth)
```

Store의 경우:

```swift
@dynamicMemberLookup
class Store<R: Reducer> {
    private var _state: State

    // State의 프로퍼티를 Store에서 직접 접근 가능하게
    subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
        _state[keyPath: keyPath]
    }
}

// 사용 예시
struct State {
    var count: Int
}

let store = Store(...)

// 원래는 이렇게 접근해야 하지만
Text("\(store.state.count)")

// @dynamicMemberLookup 덕분에 이렇게 가능
Text("\(store.count)")  // store.subscript(dynamicMember: \.count)
```

#### `public final class`

```swift
public final class Store
```

- `public`: 다른 모듈에서 사용 가능
- `final`: 상속 불가 (성능 최적화)
- `class`: 참조 타입 (struct가 아님)

**왜 class인가?**
- Store는 여러 View에서 공유되어야 함
- struct는 값 복사가 일어나므로 부적합
- class의 참조 의미론(reference semantics)이 필요

#### `<R: Reducer>`

제네릭 파라미터로, Reducer 프로토콜을 준수하는 타입만 받습니다.

```swift
class Store<R: Reducer> { ... }

// 사용 예시
struct CounterReducer: Reducer { ... }

let store = Store<CounterReducer>(...)  // R = CounterReducer
// 또는 타입 추론
let store = Store(initialState: State(), reducer: CounterReducer())
```

#### `where R.State: ObservableStateProtocol`

제네릭 제약(Generic Constraint)으로, Reducer의 State가 ObservableStateProtocol을 준수해야 합니다.

```swift
protocol Reducer {
    associatedtype State
    associatedtype Action
}

class Store<R: Reducer> where R.State: ObservableStateProtocol {
    // R.State는 ObservableStateProtocol을 준수하므로
    // _$observableKeyPaths와 hasChanged를 사용할 수 있음
}
```

**왜 필요한가?**
- KeyPath 목록과 변경 감지를 위해 ObservableStateProtocol 필수
- 이 제약이 없으면 세밀한 관찰 불가능

### 2. ObservableVersion 헬퍼 클래스

```swift
@Observable
private final class ObservableVersion {
    var value: Int = 0
}
```

KeyPath별로 독립적인 버전을 관찰 가능하게 만드는 래퍼입니다.

#### 왜 필요한가?

Dictionary는 전체를 관찰해야 하지만, 우리는 각 KeyPath를 개별적으로 관찰하고 싶습니다.

```swift
// 이렇게 하면 안 됨 (Dictionary 전체가 관찰됨)
@Observable
class Store {
    var versions: [PartialKeyPath<State>: Int] = [:]
    // versions의 어떤 키가 변경되든 전체 관찰자가 알림받음
}

// 해결: 각 버전을 Observable로 래핑
@Observable
class ObservableVersion {
    var value: Int = 0
}

class Store {
    var versions: [AnyHashable: ObservableVersion] = [:]
    // versions[keyPath].value만 관찰하면 해당 KeyPath만 독립적으로 관찰
}
```

**동작 원리**:

```swift
// View가 store.count를 읽을 때
Text("\(store.count)")

// 1. dynamicMemberLookup이 호출됨
store.subscript(dynamicMember: \.count)

// 2. 해당 KeyPath의 ObservableVersion.value를 읽음
if let version = observableVersions[AnyHashable(\.count)] {
    _ = version.value  // ← @Observable이 이 View를 관찰자로 등록
}

// 3. count가 변경되면
updateVersions(from: oldState, to: newState)
    → observableVersions[\.count]?.value += 1  // ← 관찰자에게 알림
    → Text가 다시 그려짐
```

### 3. 저장 프로퍼티

```swift
@ObservationIgnored
private var _state: State
```

#### `@ObservationIgnored`

이 프로퍼티를 @Observable의 관찰 대상에서 제외합니다.

```swift
@Observable
class Store {
    var observedProperty: Int = 0  // 자동으로 관찰됨

    @ObservationIgnored
    var notObservedProperty: Int = 0  // 관찰되지 않음
}
```

**왜 제외하나?**
- `_state`를 직접 관찰하면 전체 State가 변경될 때마다 모든 View가 업데이트됨
- 우리는 KeyPath별 세밀한 관찰을 원하므로 `_state`는 숨기고 `observableVersions`를 통해 관찰

```swift
@ObservationIgnored
private var _state: State  // 관찰 안 함

// 대신 이것들을 통해 관찰
private var observableVersions: [AnyHashable: ObservableVersion]
```

#### 나머지 프로퍼티들

```swift
@ObservationIgnored
private let reduce: (inout State, Action) -> Effect<Action>
```

- Reducer의 `reduce(into:action:)` 메서드를 저장
- 클로저로 저장하여 매번 Reducer 인스턴스를 참조하지 않아도 됨

```swift
@ObservationIgnored
private var _keyPathVersions: [PartialKeyPath<State>: Int] = [:]
```

- 각 KeyPath의 버전을 숫자로 저장
- 실제로는 사용하지 않지만, 디버깅이나 확장에 유용할 수 있음

```swift
private var observableVersions: [AnyHashable: ObservableVersion] = [:]
```

- KeyPath별 Observable 버전 저장소
- **이것이 실제로 View가 관찰하는 프로퍼티**
- `@ObservationIgnored` 없음 → 내부의 ObservableVersion들이 관찰됨

### 4. 초기화 메서드

```swift
public init(initialState: State, reducer: R) {
    self._state = initialState
    self.reduce = reducer.reduce(into:action:)

    // 모든 KeyPath의 초기 버전 설정
    for keyPath in State._$observableKeyPaths {
        _keyPathVersions[keyPath] = 0
        observableVersions[AnyHashable(keyPath)] = ObservableVersion()
    }
}
```

#### 각 줄 설명:

##### `self._state = initialState`
초기 상태를 저장합니다.

##### `self.reduce = reducer.reduce(into:action:)`
Reducer의 메서드를 클로저로 저장합니다.

```swift
// reducer.reduce(into:action:)는 메서드 참조
// 타입: (inout State, Action) -> Effect<Action>

// 이렇게 저장하면
self.reduce = reducer.reduce(into:action:)

// 나중에 이렇게 호출 가능
let effect = self.reduce(&_state, action)
```

##### `for keyPath in State._$observableKeyPaths`
State의 모든 관찰 가능한 KeyPath를 순회합니다.

```swift
// @ObservableState가 생성한 코드
extension State: ObservableStateProtocol {
    static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [\Self.count, \Self.isLoading, \Self.text]
    }
}

// 이 KeyPath들을 순회
for keyPath in [\State.count, \State.isLoading, \State.text] {
    // ...
}
```

##### `observableVersions[AnyHashable(keyPath)] = ObservableVersion()`
각 KeyPath에 대한 Observable 버전 객체를 생성합니다.

**AnyHashable이란?**

Hashable을 준수하는 모든 타입을 담을 수 있는 타입 지워진(type-erased) 래퍼입니다.

```swift
// PartialKeyPath는 Hashable이지만, 서로 다른 State 타입의 KeyPath는 다른 타입
let intKeyPath: PartialKeyPath<IntState> = \.value
let stringKeyPath: PartialKeyPath<StringState> = \.value

// 이들을 한 Dictionary에 담으려면? AnyHashable 사용
let dict: [AnyHashable: ObservableVersion] = [
    AnyHashable(intKeyPath): ObservableVersion(),
    AnyHashable(stringKeyPath): ObservableVersion()
]
```

### 5. state 프로퍼티

```swift
public var state: State {
    get {
        // 모든 KeyPath의 Observable 버전을 읽어서 전체 관찰 등록
        for keyPath in State._$observableKeyPaths {
            if let version = observableVersions[AnyHashable(keyPath)] {
                _ = version.value  // ← 관찰 등록
            }
        }
        return _state
    }
}
```

#### ⚠️ 성능 주의사항

`store.state`를 사용하면 State의 **모든 프로퍼티** 변경 시 View가 업데이트됩니다.

**비효율적인 사용:**
```swift
struct MyView: View {
    let store: Store<MyReducer>

    var body: some View {
        Text("\(store.state.count)")  // ❌ state를 통해 접근
        // → isLoading, text 등 다른 프로퍼티 변경 시에도 업데이트됨
    }
}
```

**권장 사용:**
```swift
struct OptimizedView: View {
    let store: Store<MyReducer>

    var body: some View {
        Text("\(store.count)")  // ✅ dynamicMemberLookup으로 직접 접근
        // → count 변경 시에만 업데이트
    }
}
```

#### state 프로퍼티를 사용해야 하는 경우

다음과 같은 경우에만 `state`를 사용하세요:

1. **전체 State를 함수에 전달**
   ```swift
   func processState(_ state: CounterState) { }
   processState(store.state)
   ```

2. **디버깅을 위한 전체 상태 확인**
   ```swift
   print("Current state:", store.state)
   ```

3. **State 스냅샷 저장**
   ```swift
   let snapshot = store.state  // 현재 상태 복사
   ```

### 6. dynamicMemberLookup subscript (핵심!)

```swift
public subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
    // 이 KeyPath의 ObservableVersion.value를 읽음 → @Observable이 개별 관찰 등록
    if let version = observableVersions[AnyHashable(keyPath)] {
        _ = version.value
    }
    return _state[keyPath: keyPath]
}
```

#### 동작 흐름:

```swift
// View에서 사용
Text("\(store.count)")

// 1. Swift는 이것을 이렇게 변환
store.subscript(dynamicMember: \State.count)

// 2. subscript 내부에서
// a) \.count에 해당하는 ObservableVersion 찾기
let version = observableVersions[AnyHashable(\State.count)]

// b) version.value 읽기 → @Observable이 이 View를 관찰자로 등록
_ = version.value

// c) 실제 값 반환
return _state[keyPath: \State.count]  // _state.count 반환
```

#### 왜 `_ = version.value`를 하나?

값을 사용하지 않아도 읽기 접근만으로 @Observable이 현재 View를 관찰자로 등록합니다.

```swift
@Observable
class ObservableVersion {
    var value: Int = 0
}

// View에서
Text("\(store.count)")

// subscript가 호출되고
_ = version.value  // ← 이 순간 View가 version.value의 관찰자가 됨

// 나중에 count가 변경되면
version.value += 1  // ← 관찰자(View)에게 알림 → Text가 다시 그려짐
```

### 7. send 메서드

```swift
public func send(_ action: Action) {
    let oldState = _state
    let effect = reduce(&_state, action)

    // 변경된 KeyPath만 버전 증가
    updateVersions(from: oldState, to: _state)

    handleEffect(effect)
}
```

#### 각 줄 설명:

##### `let oldState = _state`
변경 전 상태를 저장합니다 (변경 감지용).

##### `let effect = reduce(&_state, action)`
Reducer의 reduce 메서드를 호출하여 State를 업데이트하고 Effect를 받습니다.

```swift
// reduce는 이렇게 저장된 클로저
self.reduce = reducer.reduce(into:action:)

// &_state: inout 파라미터로 전달 (직접 수정됨)
let effect = reduce(&_state, action)
```

##### `updateVersions(from: oldState, to: _state)`
변경된 KeyPath들의 버전을 증가시킵니다 (다음 섹션 참조).

##### `handleEffect(effect)`
Reducer가 반환한 Effect를 실행합니다 (다음 섹션 참조).

### 8. updateVersions 메서드

```swift
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
```

#### 동작 예시:

```swift
struct State: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var text: String = ""
}

let oldState = State(count: 0, isLoading: false, text: "Hello")
let newState = State(count: 1, isLoading: false, text: "Hello")

// updateVersions 실행
for keyPath in [\State.count, \State.isLoading, \State.text] {
    if State.hasChanged(keyPath, from: oldState, to: newState) {
        observableVersions[keyPath]?.value += 1
    }
}

// 결과:
// - \.count의 버전 증가 → count를 관찰하는 View만 업데이트
// - \.isLoading의 버전 유지 → 관찰하는 View 업데이트 안 함
// - \.text의 버전 유지 → 관찰하는 View 업데이트 안 함
```

### 9. handleEffect 메서드

```swift
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
```

#### 각 부분 설명:

##### `case .none:`
부수 효과가 없으면 아무것도 하지 않습니다.

##### `case let .run(operation):`
Effect의 연관값(클로저)을 `operation`으로 추출합니다.

```swift
enum Effect<Action> {
    case none
    case run(@Sendable (_ send: Send<Action>) async -> Void)
         //  ↑ 이 클로저가 operation
}

// 패턴 매칭으로 추출
case let .run(operation):
    // operation: @Sendable (_ send: Send<Action>) async -> Void
```

##### `let send = Send<Action> { [weak self] action in await self?.send(action) }`
Send 객체를 생성하여 Effect 내부에서 Store의 send 메서드를 호출할 수 있게 합니다.

```swift
// [weak self]: 순환 참조 방지
// self?: Store가 해제되었을 수 있으므로 옵셔널 체이닝
let send = Send { [weak self] action in
    await self?.send(action)  // Store의 send 메서드 호출
}
```

##### `Task.detached { await operation(send) }`
비동기 Task를 생성하여 Effect를 백그라운드에서 실행합니다.

```swift
Task.detached {
    // 이 블록은 별도의 Task에서 실행됨 (메인 스레드 아님)
    await operation(send)
}
```

**Task.detached vs Task:**

```swift
// Task: 현재 컨텍스트(Actor)를 상속
@MainActor
func example() {
    Task {
        // 여전히 @MainActor 컨텍스트에서 실행
    }
}

// Task.detached: 독립적인 컨텍스트
@MainActor
func example() {
    Task.detached {
        // @MainActor가 아닌 백그라운드에서 실행
    }
}
```

Effect의 비동기 작업은 백그라운드에서 실행하고, 완료 후 `send`를 통해 메인 스레드로 돌아옵니다.

## 전체 흐름 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│ View                                                        │
│   Text("\(store.count)")  ← 1. count 읽기                    │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Store.subscript(dynamicMember: \.count)                     │
│   - observableVersions[\.count].value 읽기                   │
│     → @Observable이 View를 관찰자로 등록                         │
│   - return _state.count                                     │
└─────────────────────────────────────────────────────────────┘

... (사용자가 버튼 클릭) ...

┌─────────────────────────────────────────────────────────────┐
│ View                                                        │
│   Button("Increment") {                                     │
│       store.send(.increment)  ← 2. Action 전송               │
│   }                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Store.send(.increment)                                      │
│   1. oldState 저장                                           │
│   2. reduce(&_state, .increment) 호출                        │
│      → Reducer가 state.count += 1 수행                        │
│   3. updateVersions(from: oldState, to: newState)           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ Store.updateVersions()                                      │
│   for keyPath in [\.count, \.isLoading, ...] {              │
│     if State.hasChanged(keyPath, old, new) {                │
│       observableVersions[keyPath].value += 1  ← 3. 버전 증가  │
│     }                                                       │
│   }                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ @Observable 시스템                                            │
│   observableVersions[\.count].value가 변경됨                  │
│   → 이 프로퍼티를 관찰하는 View에게 알림                            │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ View 업데이트                                                 │
│   Text("\(store.count)")  ← 4. 다시 그려짐                     │
│   (isLoading이나 다른 프로퍼티를 사용하는 View는 그대로)              │
└─────────────────────────────────────────────────────────────┘
```

## 실제 사용 예시

### 예시 1: 기본 사용

```swift
@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
}

struct CounterReducer: Reducer {
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .decrement:
            state.count -= 1
            return .none
        }
    }
}

struct ContentView: View {
    @State private var store = Store(
        initialState: CounterState(),
        reducer: CounterReducer()
    )

    var body: some View {
        VStack {
            // dynamicMemberLookup으로 직접 접근
            Text("Count: \(store.count)")  // count만 관찰

            HStack {
                Button("−") { store.send(.decrement) }
                Button("+") { store.send(.increment) }
            }
        }
    }
}
```

### 예시 2: 여러 프로퍼티 사용

```swift
struct ContentView: View {
    @State private var store = Store(...)

    var body: some View {
        VStack {
            // 각 Text는 해당 프로퍼티만 관찰
            Text("Count: \(store.count)")
            // ↑ count 변경 시에만 이 Text 업데이트

            if store.isLoading {
                ProgressView()
            }
            // ↑ isLoading 변경 시에만 이 부분 업데이트

            Text(store.message ?? "No message")
            // ↑ message 변경 시에만 이 Text 업데이트
        }
    }
}
```

## 핵심 개념 정리

### 1. @MainActor
모든 UI 관련 코드를 메인 스레드에서 실행 보장

### 2. @Observable
프로퍼티별 세밀한 관찰 지원

### 3. @dynamicMemberLookup
`store.count` 문법으로 State 프로퍼티에 직접 접근

### 4. ObservableVersion
각 KeyPath를 독립적으로 관찰 가능하게 만드는 래퍼

### 5. KeyPath 기반 관찰
변경된 프로퍼티를 관찰하는 View만 업데이트

## 다음 단계

- [ObservableState 매크로](./06_ObservableState_Macro.md) - @ObservableState 매크로 사용법
- [매크로 구현](./07_ObservableStateMacro_Implementation.md) - 매크로가 코드를 생성하는 방법
