# Reducer 프로토콜

## 개요

`Reducer`는 ReducerKit의 핵심 프로토콜로, **액션에 따른 상태 변화 로직**을 정의합니다.

Reducer는 **순수 함수(Pure Function)** 로 동작하며, 현재 상태와 액션을 받아:
1. 상태를 변경하고
2. 필요한 부수 효과(Effect)를 반환합니다.

## 전체 코드

```swift
public protocol Reducer: Sendable {
    associatedtype State: Equatable
    associatedtype Action: Sendable

    func reduce(into state: inout State, action: Action) -> Effect<Action>
}
```

## 코드 상세 분석

### 1. 프로토콜 선언

```swift
public protocol Reducer: Sendable {
```

#### 각 키워드 설명:
- `public`: 이 프로토콜을 다른 모듈에서도 사용할 수 있도록 공개
- `protocol`: Swift의 프로토콜(인터페이스) 정의
- `Reducer`: 프로토콜 이름
- `: Sendable`: 이 프로토콜을 준수하는 타입은 반드시 `Sendable`도 준수해야 함
  - `Sendable`은 Swift Concurrency에서 **스레드 간 안전하게 전달 가능**함을 보장하는 프로토콜

### 2. Associated Type - State

```swift
associatedtype State: Equatable
```

#### 각 부분 설명:
- `associatedtype`: 프로토콜에서 사용할 **타입 플레이스홀더**
  - 프로토콜을 채택하는 타입이 구체적인 타입을 지정해야 함
- `State`: Associated Type의 이름
- `: Equatable`: State 타입이 반드시 `Equatable` 프로토콜을 준수해야 함
  - `Equatable`은 두 값을 `==`로 비교 가능하게 만드는 프로토콜
  - SwiftUI가 상태 변경을 감지하고 View 업데이트를 최적화하는 데 필요

#### 사용 예시:
```swift
struct CounterReducer: Reducer {
    // State를 구체적인 타입으로 지정
    struct State: Equatable {  // ← Equatable 준수 필수
        var count: Int = 0
        var isLoading: Bool = false
    }
    // ...
}
```

### 3. Associated Type - Action

```swift
associatedtype Action: Sendable
```

#### 각 부분 설명:
- `associatedtype Action`: View에서 발생할 수 있는 모든 동작을 정의하는 타입
- `: Sendable`: Action이 스레드 간 안전하게 전달될 수 있어야 함
  - 비동기 작업에서 Action을 전달하므로 Sendable 준수 필수

#### 사용 예시:
```swift
struct CounterReducer: Reducer {
    enum Action {  // ← enum은 자동으로 Sendable
        case increment
        case decrement
        case reset
        case fetchNumberFact
        case numberFactLoaded(String)
    }
    // ...
}
```

### 4. reduce 메서드

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action>
```

이 메서드가 Reducer의 핵심입니다.

#### 각 부분 설명:

##### `into state: inout State`
- `inout`: **참조로 전달**하여 함수 내부에서 직접 수정 가능
- 왜 `inout`을 사용하나요?
  - 성능 최적화: 값 복사 없이 직접 수정
  - 명확한 의도: 이 파라미터가 변경된다는 것을 명시적으로 표현

```swift
// inout 사용 예시
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .increment:
        state.count += 1  // ← state를 직접 수정
        return .none
    }
}
```

##### `action: Action`
- 처리할 액션 (값으로 전달)

##### `-> Effect<Action>`
- 반환 타입: `Effect<Action>`
- 부수 효과가 없으면 `.none` 반환
- 비동기 작업이 필요하면 `.run { ... }` 반환

## 실제 구현 예시

### 기본 예시 - 부수 효과 없음

```swift
struct CounterReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
    }

    enum Action {
        case increment
        case decrement
        case reset
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1  // 상태만 변경
            return .none      // 부수 효과 없음

        case .decrement:
            state.count -= 1
            return .none

        case .reset:
            state.count = 0
            return .none
        }
    }
}
```

### 고급 예시 - 비동기 작업 포함

```swift
struct TodoReducer: Reducer {
    struct State: Equatable {
        var todos: [Todo] = []
        var isLoading: Bool = false
    }

    enum Action {
        case fetchTodos
        case todosLoaded([Todo])
        case todosFailed(Error)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .fetchTodos:
            state.isLoading = true  // 상태 변경

            // 비동기 작업을 Effect로 반환
            return .run { send in
                do {
                    let todos = try await apiClient.fetchTodos()
                    await send(.todosLoaded(todos))  // 성공 시 새 액션 전송
                } catch {
                    await send(.todosFailed(error))   // 실패 시 에러 액션 전송
                }
            }

        case .todosLoaded(let todos):
            state.isLoading = false
            state.todos = todos
            return .none

        case .todosFailed(let error):
            state.isLoading = false
            // 에러 처리 로직
            return .none
        }
    }
}
```

## 핵심 개념 정리

### Associated Type이란?

프로토콜에서 "구체적인 타입은 나중에 정하겠다"는 타입 플레이스홀더입니다.

```swift
// Associated Type 사용 전
protocol Container {
    func add(item: Int)  // Int로 고정
}

// Associated Type 사용 후
protocol Container {
    associatedtype Item   // 나중에 정할 타입
    func add(item: Item)
}

struct IntContainer: Container {
    typealias Item = Int  // 여기서 구체적 타입 지정 (생략 가능)
    func add(item: Int) { }
}

struct StringContainer: Container {
    // typealias 생략 가능 - Swift가 추론
    func add(item: String) { }  // Item = String으로 자동 추론
}
```

### inout이란?

함수 파라미터를 참조로 전달하여 함수 내부에서 직접 수정할 수 있게 합니다.

```swift
// inout 없이
func incrementCopy(_ number: Int) -> Int {
    var mutableNumber = number
    mutableNumber += 1
    return mutableNumber  // 새 값을 반환해야 함
}
var count = 5
count = incrementCopy(count)  // 재할당 필요

// inout 사용
func incrementInPlace(_ number: inout Int) {
    number += 1  // 직접 수정
}
var count = 5
incrementInPlace(&count)  // & 기호로 참조 전달
```

## 왜 이렇게 설계했나?

### 1. Sendable 제약
- Swift Concurrency 환경에서 안전한 사용을 보장
- 여러 스레드에서 동시에 접근해도 데이터 경쟁 발생 안 함

### 2. Equatable 제약 (State)
- SwiftUI가 상태 변경을 효율적으로 감지
- 변경되지 않은 부분은 다시 그리지 않음 (최적화)

### 3. inout 사용
- 값 복사 없이 직접 수정하여 성능 최적화
- "상태가 변경된다"는 의도를 명확히 표현

### 4. Effect 반환
- 순수 함수 유지: 부수 효과를 반환값으로 분리
- 테스트 용이성: 상태 변경과 부수 효과를 독립적으로 테스트 가능
