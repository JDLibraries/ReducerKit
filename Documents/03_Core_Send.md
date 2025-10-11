# Send 타입

## 개요

`Send`는 Effect 내부에서 새로운 Action을 Store로 전송하기 위한 래퍼 구조체입니다.

비동기 작업이 완료된 후 결과를 State에 반영하려면 새로운 Action을 전송해야 하는데, Send가 그 인터페이스를 제공합니다.

## 전체 코드

```swift
public struct Send<Action: Sendable>: Sendable {
    let send: @Sendable (Action) async -> Void

    public init(_ send: @escaping @Sendable (Action) async -> Void) {
        self.send = send
    }

    public func callAsFunction(_ action: Action) async {
        await send(action)
    }
}
```

## 왜 Send가 필요한가?

### Effect에서 액션을 전송하는 방법

Effect의 `.run` case를 사용할 때, 비동기 작업 완료 후 결과를 어떻게 State에 반영할까요?

```swift
return .run { send in
    let data = await apiClient.fetch()
    // 이제 data를 State에 어떻게 반영하지? 🤔
}
```

Send 객체를 통해 새로운 Action을 전송합니다:

```swift
return .run { send in
    let data = await apiClient.fetch()
    await send(.dataLoaded(data))  // ← Send를 통해 새 액션 전송
}
```

이렇게 전송된 `.dataLoaded(data)` 액션은 다시 Reducer의 `reduce` 메서드로 전달됩니다:

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .fetchData:
        return .run { send in
            let data = await apiClient.fetch()
            await send(.dataLoaded(data))  // 이 액션이 다시 reduce로 전달됨
        }

    case .dataLoaded(let data):  // ← 여기서 처리됨
        state.data = data
        return .none
    }
}
```

## 코드 상세 분석

### 1. struct 선언

```swift
public struct Send<Action: Sendable>: Sendable {
```

#### 각 부분 설명:
- `struct`: 값 타입 구조체
- `Send`: 타입 이름
- `<Action: Sendable>`: 제네릭 파라미터
  - Action은 어떤 타입이든 가능하지만 Sendable을 준수해야 함
- `: Sendable`: Send 자체도 Sendable을 준수
  - 구조체의 모든 프로퍼티가 Sendable이면 구조체도 자동으로 Sendable

### 2. send 프로퍼티

```swift
let send: @Sendable (Action) async -> Void
```

실제 액션을 전송하는 클로저를 저장합니다.

#### 각 부분 설명:

##### `let send: ...`
- 불변 프로퍼티로 클로저를 저장
- `let`이므로 한번 초기화되면 변경 불가

##### `@Sendable (Action) async -> Void`
- `@Sendable`: 이 클로저가 스레드 간 안전하게 전달 가능
- `(Action)`: Action을 파라미터로 받음
- `async`: 비동기 함수
- `-> Void`: 반환값 없음

이 클로저는 나중에 Store의 `send(_:)` 메서드와 연결됩니다.

### 3. init 메서드

```swift
public init(_ send: @escaping @Sendable (Action) async -> Void) {
    self.send = send
}
```

Send 객체를 초기화합니다.

#### 각 부분 설명:

##### `_` (와일드카드)
외부 파라미터 레이블 생략:

```swift
// _ 없이
let sender = Send(send: { action in ... })

// _ 사용 (실제 코드)
let sender = Send({ action in ... })
```

##### `@escaping`
이 클로저가 함수 실행이 끝난 후에도 살아남을 수 있음을 의미합니다.

```swift
// escaping이 필요한 경우
struct Example {
    var closure: () -> Void  // 프로퍼티로 저장

    init(closure: @escaping () -> Void) {  // @escaping 필수
        self.closure = closure  // 함수가 끝난 후에도 클로저가 살아있음
    }
}

// escaping이 필요없는 경우
func execute(closure: () -> Void) {
    closure()  // 함수 내부에서만 사용하고 끝
}
```

Send의 경우, 클로저를 프로퍼티로 저장하므로 `@escaping`이 필요합니다.

##### `@Sendable`
클로저가 스레드 간 안전하게 전달될 수 있음을 보장:

```swift
Task.detached {  // 다른 스레드에서 실행
    await send(action)  // @Sendable 클로저이므로 안전
}
```

### 4. callAsFunction 메서드

```swift
public func callAsFunction(_ action: Action) async {
    await send(action)
}
```

이 메서드가 **Send를 함수처럼 호출**할 수 있게 만듭니다.

#### callAsFunction이란?

Swift의 특별한 메서드로, 객체를 함수처럼 호출할 수 있게 합니다.

```swift
struct Adder {
    let value: Int

    // callAsFunction을 정의하면
    func callAsFunction(_ x: Int) -> Int {
        return x + value
    }
}

let addFive = Adder(value: 5)

// 일반 메서드 호출
let result1 = addFive.callAsFunction(10)  // 15

// 함수처럼 호출 (더 간단!)
let result2 = addFive(10)  // 15
```

Send의 경우:

```swift
// callAsFunction이 없다면
await send.send(.action)  // 프로퍼티에 직접 접근

// callAsFunction 덕분에
await send(.action)  // 함수처럼 간단하게 호출
```

## 전체 흐름 이해하기

Send가 어떻게 작동하는지 전체 흐름을 살펴봅시다.

### 1. Store에서 Send 객체 생성

Store의 `handleEffect` 메서드에서 Send를 생성합니다 (Store.swift:152):

```swift
private func handleEffect(_ effect: Effect<Action>) {
    switch effect {
    case .none:
        break

    case let .run(operation):
        // Send 객체 생성 - Store의 send 메서드와 연결
        let send = Send<Action> { [weak self] action in
            await self?.send(action)  // ← Store의 send(_:) 메서드 호출
        }

        Task.detached {
            await operation(send)  // Effect에 Send 전달
        }
    }
}
```

#### 각 부분 설명:

##### `[weak self]` 캡처 리스트
클로저가 self를 약한 참조로 캡처하여 순환 참조를 방지:

```swift
// 강한 참조 (순환 참조 위험)
let closure = {
    self.doSomething()  // self를 강하게 참조
}

// 약한 참조 (순환 참조 방지)
let closure = { [weak self] in
    self?.doSomething()  // self가 nil일 수 있음
}
```

Store가 해제되면 send 클로저도 안전하게 종료됩니다.

##### `await self?.send(action)`
- `self?`: self가 nil일 수 있으므로 옵셔널 체이닝 사용
- `.send(action)`: Store의 `send(_:)` 메서드 호출 (Store.swift:114)
- `await`: send 메서드가 비동기이므로 대기

### 2. Effect에서 Send 사용

Reducer가 반환한 Effect에서 Send를 받아 사용합니다:

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .fetchData:
        return .run { send in  // ← Store가 전달한 Send 객체
            let data = await apiClient.fetch()
            await send(.dataLoaded(data))  // callAsFunction 호출
        }
    }
}
```

### 3. callAsFunction을 통한 액션 전송

```swift
await send(.dataLoaded(data))
```

이 한 줄이 실제로 하는 일:

```swift
// 1. callAsFunction 메서드 호출
await send.callAsFunction(.dataLoaded(data))

// 2. callAsFunction 내부에서 send 프로퍼티 호출
await self.send(.dataLoaded(data))

// 3. send 프로퍼티는 Store의 send 메서드와 연결됨
await store.send(.dataLoaded(data))

// 4. Store의 send 메서드가 Reducer의 reduce 호출
let effect = reduce(&_state, .dataLoaded(data))
```

### 4. Reducer에서 새 액션 처리

```swift
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .dataLoaded(let data):  // ← Send를 통해 전송된 액션
        state.data = data
        return .none
    }
}
```

## 실제 사용 예시

### 예시 1: 기본 비동기 작업

```swift
struct CounterReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
        var fact: String?
    }

    enum Action {
        case fetchFact
        case factLoaded(String)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .fetchFact:
            let count = state.count

            return .run { send in
                // API 호출
                let fact = await numbersAPI.fetchFact(for: count)

                // Send를 통해 결과 전송
                await send(.factLoaded(fact))
                //    ↑ callAsFunction 호출
                //    → send 프로퍼티 호출
                //    → Store.send(_:) 호출
                //    → reduce(state, .factLoaded(fact)) 호출
            }

        case .factLoaded(let fact):
            state.fact = fact
            return .none
        }
    }
}
```

### 예시 2: 여러 액션 연속 전송

```swift
return .run { send in
    // 1. 로딩 시작 알림
    await send(.loadingStarted)

    do {
        // 2. 데이터 가져오기
        let data = try await apiClient.fetch()

        // 3. 성공 알림
        await send(.dataLoaded(data))

    } catch {
        // 4. 실패 알림
        await send(.loadingFailed(error))
    }

    // 5. 로딩 종료 알림
    await send(.loadingFinished)
}
```

### 예시 3: 조건부 액션 전송

```swift
return .run { send in
    let results = await searchAPI.search(query: query)

    if results.isEmpty {
        await send(.noResultsFound)
    } else {
        await send(.resultsLoaded(results))
    }

    // 분석 이벤트 전송
    await send(.analyticsEvent(.searchPerformed(
        query: query,
        resultCount: results.count
    )))
}
```

## 핵심 개념 정리

### 1. @escaping 클로저

함수 실행이 끝난 후에도 살아있는 클로저:

```swift
var savedClosures: [() -> Void] = []

func saveForLater(closure: @escaping () -> Void) {
    savedClosures.append(closure)  // 나중에 실행하기 위해 저장
}

func execute(closure: () -> Void) {
    closure()  // 즉시 실행만 하므로 @escaping 불필요
}
```

### 2. 캡처 리스트 (Capture List)

클로저가 외부 변수를 어떻게 참조할지 지정:

```swift
class Example {
    var value = 0

    func test() {
        // 강한 참조 (순환 참조 위험)
        let closure1 = {
            self.value += 1
        }

        // 약한 참조 (순환 참조 방지)
        let closure2 = { [weak self] in
            self?.value += 1
        }

        // 값 캡처 (복사본 사용)
        let closure3 = { [value] in
            print(value)  // 현재 값의 복사본
        }
    }
}
```

### 3. callAsFunction

객체를 함수처럼 호출 가능하게 만드는 특별한 메서드:

```swift
struct Multiplier {
    let factor: Int

    func callAsFunction(_ value: Int) -> Int {
        return value * factor
    }
}

let triple = Multiplier(factor: 3)
print(triple(5))  // 15 - 함수처럼 호출
```

## 다이어그램: Send의 데이터 흐름

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Reducer가 Effect 반환                                      │
│    return .run { send in                                     │
│        await send(.action)                                   │
│    }                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Store가 Send 객체 생성                                     │
│    let send = Send { [weak self] action in                  │
│        await self?.send(action)  // Store의 send 메서드       │
│    }                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Effect가 Send를 받아 실행                                  │
│    Task.detached {                                           │
│        await operation(send)  // Effect 클로저에 Send 전달    │
│    }                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Effect 내부에서 Send 호출                                  │
│    await send(.dataLoaded(data))  // callAsFunction 호출     │
│          ↓                                                   │
│    await send.callAsFunction(.dataLoaded(data))             │
│          ↓                                                   │
│    await send.send(.dataLoaded(data))  // 프로퍼티 호출       │
│          ↓                                                   │
│    await store.send(.dataLoaded(data))  // Store의 메서드     │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Store가 Reducer의 reduce 호출                             │
│    let effect = reduce(&_state, .dataLoaded(data))          │
└─────────────────────────────────────────────────────────────┘
```

## 왜 이렇게 설계했나?

### 1. 클로저 래핑
- Effect 내부에서 Store에 직접 접근하지 않고 인터페이스를 통해 통신
- 의존성을 명확하게 분리
- 테스트에서 Mock Send를 쉽게 주입 가능

### 2. callAsFunction 사용
- `await send(.action)` - 간결하고 직관적
- `await send.send(.action)` - 중복되고 장황함

### 3. @escaping + @Sendable
- 비동기 Task에서 안전하게 사용
- 스레드 간 안전한 전달 보장

## 다음 단계

- [Store 타입](./04_Store.md) - Send를 생성하고 Effect를 실행하는 방법
- [ObservableState 프로토콜](./05_ObservableStateProtocol.md) - 세밀한 관찰을 위한 프로토콜
