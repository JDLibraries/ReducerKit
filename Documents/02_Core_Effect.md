# Effect 타입

## 개요

`Effect`는 Reducer가 상태 변경 후 실행해야 하는 **부수 효과(Side Effect)** 를 표현하는 타입입니다.

Reducer는 순수 함수로 유지하고, 비동기 작업이나 외부 의존성이 필요한 작업은 Effect로 반환하여 Store가 처리하도록 합니다.

## 전체 코드

```swift
public enum Effect<Action: Sendable>: Sendable {
    case none
    case run(@Sendable (_ send: Send<Action>) async -> Void)
}
```

## 왜 Effect가 필요한가?

### 문제: Reducer에서 직접 비동기 작업을 할 수 없다

```swift
// ❌ 잘못된 예시
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .fetchData:
        // Reducer는 순수 함수여야 하는데 비동기 작업을 직접 수행할 수 없음
        let data = await apiClient.fetch()  // 컴파일 에러!
        state.data = data
        return .none
    }
}
```

### 해결: Effect로 비동기 작업을 반환

```swift
// ✅ 올바른 예시
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .fetchData:
        state.isLoading = true  // 상태만 즉시 변경

        // 비동기 작업은 Effect로 반환
        return .run { send in
            let data = await apiClient.fetch()
            await send(.dataLoaded(data))  // 완료 후 새 액션 전송
        }

    case .dataLoaded(let data):
        state.isLoading = false
        state.data = data
        return .none
    }
}
```

## 코드 상세 분석

### 1. enum 선언

```swift
public enum Effect<Action: Sendable>: Sendable {
```

#### 각 부분 설명:
- `enum`: Swift의 열거형 타입
- `Effect`: 타입 이름
- `<Action: Sendable>`: 제네릭 파라미터
  - `Action`이라는 타입 플레이스홀더를 선언
  - `Action`은 반드시 `Sendable` 프로토콜을 준수해야 함
- `: Sendable`: Effect 자체도 Sendable을 준수
  - enum의 모든 연관값(associated value)이 Sendable이면 enum도 자동으로 Sendable

#### 제네릭이란?

"구체적인 타입은 나중에 정하겠다"는 의미입니다.

```swift
// 제네릭 없이
enum IntEffect {
    case none
    case run((_ send: Send<Int>) async -> Void)
}

enum StringEffect {
    case none
    case run((_ send: Send<String>) async -> Void)
}

// 제네릭 사용
enum Effect<Action> {  // Action은 어떤 타입이든 가능
    case none
    case run((_ send: Send<Action>) async -> Void)
}

// 사용 시 구체적 타입 지정
let intEffect: Effect<Int> = .none
let stringEffect: Effect<String> = .none
```

### 2. case none

```swift
case none
```

#### 설명:
- 추가 작업이 없음을 나타냄
- 상태만 변경하고 부수 효과가 없을 때 사용

#### 사용 예시:
```swift
func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .increment:
        state.count += 1
        return .none  // ← 카운트만 증가하고 끝
    }
}
```

### 3. case run

```swift
case run(@Sendable (_ send: Send<Action>) async -> Void)
```

이 부분이 가장 복잡하므로 하나씩 분해해봅시다.

#### 전체 구조:
```swift
case run(
    @Sendable                      // 1. 클로저가 Sendable임을 명시
    (_ send: Send<Action>)         // 2. 클로저의 파라미터
    async                          // 3. 비동기 함수임을 명시
    -> Void                        // 4. 반환 타입 (없음)
)
```

#### 1. `@Sendable` 어트리뷰트

```swift
@Sendable (_ send: Send<Action>) async -> Void
```

- 이 클로저가 스레드 간 안전하게 전달될 수 있음을 컴파일러에게 알림
- Swift Concurrency에서 클로저를 Task로 전달할 때 필요

```swift
// @Sendable이 필요한 이유
Task.detached {  // 다른 스레드에서 실행
    await operation(send)  // operation이 @Sendable이어야 안전
}
```

#### 2. 클로저 파라미터: `_ send: Send<Action>`

```swift
(_ send: Send<Action>) async -> Void
```

- `_`: 외부 파라미터 이름 생략 (호출 시 레이블 없이 사용)
- `send`: 내부 파라미터 이름
- `Send<Action>`: 파라미터 타입
  - `Send`는 Effect 내부에서 새로운 Action을 Store로 전송하는 객체

#### 파라미터 레이블이란?

Swift에서 함수 파라미터는 외부 이름과 내부 이름을 가질 수 있습니다.

```swift
// 외부 이름과 내부 이름이 다른 경우
func greet(to name: String) {
    print("Hello, \(name)")  // 내부에서는 'name' 사용
}
greet(to: "Alice")  // 호출 시에는 'to' 레이블 사용

// 외부 이름 생략 (_)
func greet(_ name: String) {
    print("Hello, \(name)")
}
greet("Alice")  // 레이블 없이 호출

// Effect의 경우
return .run { send in  // ← 레이블 없이 바로 클로저 시작
    await send(.action)
}
```

#### 3. `async` 키워드

```swift
(_ send: Send<Action>) async -> Void
```

- 이 클로저가 비동기 함수임을 나타냄
- 내부에서 `await` 키워드를 사용할 수 있음

```swift
return .run { send in
    // async 클로저이므로 await 사용 가능
    let data = await apiClient.fetch()
    await send(.dataLoaded(data))
}
```

#### 4. `-> Void` 반환 타입

```swift
(_ send: Send<Action>) async -> Void
```

- 클로저가 아무것도 반환하지 않음
- `Void`는 빈 튜플 `()`과 같은 의미

```swift
// 다음 세 가지는 모두 같은 의미
async -> Void
async -> ()
async  // 반환 타입 생략 가능
```

## 연관값(Associated Value)이란?

enum의 각 case가 추가 데이터를 가질 수 있습니다.

```swift
// 연관값이 없는 enum
enum TrafficLight {
    case red
    case yellow
    case green
}

// 연관값이 있는 enum
enum Result {
    case success(String)    // String 데이터를 함께 저장
    case failure(Error)     // Error 데이터를 함께 저장
}

let result = Result.success("Done!")

switch result {
case .success(let message):
    print(message)  // "Done!" 출력
case .failure(let error):
    print(error)
}
```

Effect의 `.run` case도 클로저를 연관값으로 가집니다:

```swift
// Effect 정의
enum Effect<Action: Sendable> {
    case none
    case run(@Sendable (_ send: Send<Action>) async -> Void)
           // ↑ 이 클로저가 연관값
}

// 사용 예시
let effect: Effect<MyAction> = .run { send in
    await send(.action)
}
// ↑ 클로저가 .run case의 연관값으로 저장됨
```

## 실제 사용 예시

### 예시 1: API 호출

```swift
struct UserReducer: Reducer {
    struct State: Equatable {
        var user: User?
        var isLoading: Bool = false
        var error: String?
    }

    enum Action {
        case fetchUser(id: String)
        case userLoaded(User)
        case userFailed(Error)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .fetchUser(let id):
            state.isLoading = true
            state.error = nil

            // 비동기 API 호출을 Effect로 반환
            return .run { send in
                do {
                    let user = try await apiClient.fetchUser(id: id)
                    await send(.userLoaded(user))
                } catch {
                    await send(.userFailed(error))
                }
            }

        case .userLoaded(let user):
            state.isLoading = false
            state.user = user
            return .none

        case .userFailed(let error):
            state.isLoading = false
            state.error = error.localizedDescription
            return .none
        }
    }
}
```

### 예시 2: 타이머

```swift
struct TimerReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
    }

    enum Action {
        case startTimer
        case timerTicked
        case stopTimer
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .startTimer:
            // 1초마다 timerTicked 액션을 전송하는 Effect
            return .run { send in
                for _ in 0..<10 {  // 10번 반복
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await send(.timerTicked)
                }
            }

        case .timerTicked:
            state.count += 1
            return .none

        case .stopTimer:
            // TODO: 타이머 취소 로직 (고급 주제)
            return .none
        }
    }
}
```

### 예시 3: 여러 비동기 작업 조합

```swift
struct AppReducer: Reducer {
    struct State: Equatable {
        var user: User?
        var posts: [Post] = []
    }

    enum Action {
        case loadUserAndPosts
        case userLoaded(User)
        case postsLoaded([Post])
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadUserAndPosts:
            // 사용자 정보와 게시글을 동시에 불러오기
            return .run { send in
                async let user = apiClient.fetchUser()
                async let posts = apiClient.fetchPosts()

                // 두 작업이 모두 완료될 때까지 대기
                let (loadedUser, loadedPosts) = try await (user, posts)

                await send(.userLoaded(loadedUser))
                await send(.postsLoaded(loadedPosts))
            }

        case .userLoaded(let user):
            state.user = user
            return .none

        case .postsLoaded(let posts):
            state.posts = posts
            return .none
        }
    }
}
```

## 핵심 개념 정리

### 1. 제네릭 (Generic)

구체적인 타입을 나중에 결정하는 방식:

```swift
// 제네릭 없이 - 각 타입마다 별도 구현 필요
struct IntBox {
    var value: Int
}
struct StringBox {
    var value: String
}

// 제네릭 사용 - 하나의 구현으로 모든 타입 지원
struct Box<T> {
    var value: T
}

let intBox = Box(value: 42)
let stringBox = Box(value: "Hello")
```

### 2. 클로저 (Closure)

이름 없는 함수를 값처럼 다룰 수 있는 기능:

```swift
// 일반 함수
func greet(name: String) -> String {
    return "Hello, \(name)"
}

// 클로저 (간단한 형태)
let greetClosure = { (name: String) -> String in
    return "Hello, \(name)"
}

// 더 간단하게
let greet: (String) -> String = { name in
    "Hello, \(name)"
}

// Effect에서 클로저 사용
return .run { send in  // ← 클로저 시작
    await send(.action)
}
```

### 3. 비동기 (async/await)

비동기 작업을 동기 코드처럼 작성:

```swift
// 옛날 방식 (콜백)
func fetchData(completion: @escaping (Data) -> Void) {
    URLSession.shared.dataTask(with: url) { data, _, _ in
        completion(data!)
    }.resume()
}

// 현대적 방식 (async/await)
func fetchData() async -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}

// Effect에서 사용
return .run { send in
    let data = await fetchData()  // 비동기 대기
    await send(.dataLoaded(data))
}
```

## 왜 이렇게 설계했나?

### 1. Reducer를 순수 함수로 유지
- 상태 변경 로직과 부수 효과를 분리
- 테스트가 쉬워짐
- 예측 가능한 동작

### 2. enum으로 표현
- `.none`과 `.run` 두 가지 경우만 존재
- 타입 안전성: 컴파일러가 모든 케이스를 검사
- 명확한 의도 표현

### 3. Send를 파라미터로 제공
- Effect 내부에서 Store로 액션을 전송할 수 있는 방법 제공
- 비동기 작업 완료 후 결과를 State에 반영 가능

## 다음 단계

- [Send 타입](./03_Core_Send.md) - Effect 내부에서 액션을 전송하는 방법
- [Store 타입](./04_Store.md) - Effect를 실제로 실행하는 방법
