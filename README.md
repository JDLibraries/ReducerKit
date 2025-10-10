# ReducerKit

SwiftUI 애플리케이션을 위한 경량 단방향 상태 관리 라이브러리로, The Composable Architecture (TCA)에서 영감을 받았습니다.

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20macOS%2014+%20|%20tvOS%2017+%20|%20watchOS%2010+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com/xcode/)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## 개요

ReducerKit은 단방향 데이터 플로우 패턴을 사용하여 SwiftUI 애플리케이션의 상태를 관리하는 간단하면서도 강력한 방법을 제공합니다. 예측 가능하고, 테스트 가능하며, 유지보수가 쉬운 애플리케이션을 만들 수 있습니다.

### 주요 특징

- **단방향 데이터 플로우**: 명확하고 예측 가능한 상태 관리 패턴
- **타입 안전**: Swift의 타입 시스템을 활용한 컴파일 타임 안전성
- **부수 효과 관리**: 상태 변경과 비동기 작업의 명확한 분리
- **SwiftUI 통합**: `@Observable`을 기반으로 한 원활한 SwiftUI 통합
- **동시성 안전**: `@MainActor`와 `Sendable`을 활용한 완전한 Swift Concurrency 지원
- **경량**: 최소한의 의존성과 간단한 API
- **테스트 가능**: Reducer와 상태 변경을 쉽게 테스트

## 요구사항

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+ / visionOS 1.0+
- Swift 6.2+
- Xcode 16.0+

## 설치

### Swift Package Manager

Swift Package Manager를 사용하여 프로젝트에 ReducerKit을 추가하세요:

1. Xcode에서 **File > Add Package Dependencies...** 선택
2. 저장소 URL 입력:
```
https://github.com/yourusername/ReducerKit
```
3. 사용할 버전 선택

또는 `Package.swift` 파일에 직접 추가:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ReducerKit", from: "1.0.0")
]
```

## 핵심 개념

### State (상태)

State는 기능이 표시하고 동작하는 데 필요한 모든 데이터를 나타냅니다. 효율적인 변경 감지를 위해 `Equatable`을 준수해야 합니다.

```swift
struct State: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var errorMessage: String?
}
```

### Action (액션)

Action은 사용자 상호작용이나 시스템 이벤트 등 기능에서 발생할 수 있는 모든 이벤트를 나타냅니다.

```swift
enum Action: Sendable {
    case increment
    case decrement
    case fetchData
    case dataReceived(Result<Data, Error>)
}
```

### Reducer (리듀서)

`Reducer` 프로토콜은 액션에 대한 응답으로 상태가 어떻게 변경되는지를 정의합니다. 현재 상태와 액션을 받아 새로운 상태와 선택적 부수 효과를 반환하는 순수 함수입니다.

```swift
struct MyReducer: Reducer {
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .decrement:
            state.count -= 1
            return .none

        case .fetchData:
            state.isLoading = true
            return .run { send in
                let data = await api.fetch()
                await send(.dataReceived(.success(data)))
            }

        case let .dataReceived(result):
            state.isLoading = false
            // 결과 처리...
            return .none
        }
    }
}
```

### Effect (부수 효과)

Effect는 네트워크 요청, 타이머 또는 모든 비동기 작업과 같은 부수 효과를 나타냅니다. Reducer를 순수하게 유지하면서도 필요한 비동기 작업을 수행할 수 있게 해줍니다.

```swift
// 부수 효과 없음
return .none

// 콜백이 있는 비동기 작업
return .run { send in
    let result = await performAsyncWork()
    await send(.workCompleted(result))
}
```

### Store (스토어)

`Store`는 모든 것을 조율합니다 - 상태를 보유하고, Reducer를 통해 액션을 처리하며, 부수 효과를 관리합니다.

```swift
let store = Store(
    initialState: MyReducer.State(),
    reducer: MyReducer()
)
```

## 사용법

### 기본 예제: 카운터

비동기 숫자 팩트 기능이 있는 카운터 기능의 완전한 예제입니다:

#### 1. Reducer 정의

```swift
import ReducerKit

struct CounterReducer: Reducer {
    struct State: Equatable {
        var count: Int = 0
        var isLoading: Bool = false
        var numberFact: String?
    }

    enum Action: Sendable {
        case increment
        case decrement
        case numberFactButtonTapped
        case numberFactResponse(String)
    }

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
            return .run { [count = state.count] send in
                do {
                    let (data, _) = try await URLSession.shared.data(
                        from: URL(string: "http://numbersapi.com/\(count)/trivia")!
                    )
                    let fact = String(decoding: data, as: UTF8.self)
                    await send(.numberFactResponse(fact))
                } catch {
                    await send(.numberFactResponse("팩트를 불러오는데 실패했습니다"))
                }
            }

        case let .numberFactResponse(fact):
            state.isLoading = false
            state.numberFact = fact
            return .none
        }
    }
}
```

#### 2. View 생성

```swift
import SwiftUI
import ReducerKit

struct CounterView: View {
    @State private var store = Store(
        initialState: CounterReducer.State(),
        reducer: CounterReducer()
    )

    var body: some View {
        VStack(spacing: 40) {
            Text("\(store.state.count)")
                .font(.system(size: 80, weight: .bold))

            HStack(spacing: 16) {
                Button("+") {
                    store.send(.increment)
                }

                Button("-") {
                    store.send(.decrement)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("숫자 팩트 가져오기") {
                store.send(.numberFactButtonTapped)
            }
            .disabled(store.state.isLoading)

            if let fact = store.state.numberFact {
                Text(fact)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
```

### 고급 예제: API 통합

```swift
struct TodosReducer: Reducer {
    struct State: Equatable {
        var todos: [Todo] = []
        var isLoading: Bool = false
        var error: String?
    }

    enum Action: Sendable {
        case loadTodos
        case todosLoaded(Result<[Todo], Error>)
        case addTodo(String)
        case todoAdded(Todo)
        case toggleTodo(Todo.ID)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .loadTodos:
            state.isLoading = true
            state.error = nil
            return .run { send in
                let result = await TodoAPI.fetchTodos()
                await send(.todosLoaded(result))
            }

        case let .todosLoaded(.success(todos)):
            state.isLoading = false
            state.todos = todos
            return .none

        case let .todosLoaded(.failure(error)):
            state.isLoading = false
            state.error = error.localizedDescription
            return .none

        case let .addTodo(title):
            return .run { send in
                let todo = await TodoAPI.createTodo(title: title)
                await send(.todoAdded(todo))
            }

        case let .todoAdded(todo):
            state.todos.append(todo)
            return .none

        case let .toggleTodo(id):
            guard let index = state.todos.firstIndex(where: { $0.id == id }) else {
                return .none
            }
            state.todos[index].isCompleted.toggle()
            return .none
        }
    }
}
```

## 테스트

ReducerKit을 사용하면 상태 로직을 쉽게 테스트할 수 있습니다:

```swift
import XCTest
@testable import YourApp
import ReducerKit

final class CounterReducerTests: XCTestCase {
    func testIncrement() {
        var state = CounterReducer.State(count: 0)
        let reducer = CounterReducer()

        let effect = reducer.reduce(into: &state, action: .increment)

        XCTAssertEqual(state.count, 1)
        XCTAssertEqual(effect, .none)
    }

    func testDecrement() {
        var state = CounterReducer.State(count: 5)
        let reducer = CounterReducer()

        let effect = reducer.reduce(into: &state, action: .decrement)

        XCTAssertEqual(state.count, 4)
        XCTAssertEqual(effect, .none)
    }

    func testNumberFactRequest() {
        var state = CounterReducer.State(count: 42)
        let reducer = CounterReducer()

        let effect = reducer.reduce(into: &state, action: .numberFactButtonTapped)

        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.numberFact)
        // Effect 테스트는 추가 설정이 필요합니다
    }
}
```

## 아키텍처

ReducerKit은 단방향 데이터 플로우를 따릅니다:

<img width="700" alt="111" src="https://github.com/user-attachments/assets/cc3063c2-c39d-4231-b1ba-8f82123dde92" />

1. **View**가 **Store**에 **Action**을 보냄
2. **Store**가 현재 상태와 액션으로 **Reducer**를 호출
3. **Reducer**가 상태를 업데이트하고 **Effect**를 반환
4. **Store**가 **Effect**를 실행 (있는 경우)
5. **Effect**가 비동기 작업을 수행하고 새로운 **Action**을 보냄
6. 사이클 반복...

## 모범 사례

1. **Reducer를 순수하게 유지**: Reducer는 상태만 수정해야 하며, 직접 부수 효과를 수행하면 안 됩니다
2. **비동기 작업에 Effect 사용**: 모든 비동기 작업은 Effect를 통해야 합니다
3. **Effect에서 값 캡처**: 경쟁 조건을 피하기 위해 Effect를 생성할 때 필요한 상태 값을 캡처하세요
4. **단일 진실 공급원**: 모든 기능 상태를 하나의 State 구조체에 보관하세요
5. **Action 구성**: 도메인별로 액션을 구성하기 위해 중첩된 enum을 사용하세요
6. **Reducer 테스트**: 부수 효과와 독립적으로 상태 변경을 테스트하세요

## 예제

완전한 샘플 프로젝트는 `Examples` 디렉토리를 확인하세요:

- **Counter**: 비동기 숫자 팩트가 있는 기본 카운터
- 더 많은 예제가 곧 추가됩니다!

## 기여하기

기여를 환영합니다! Pull Request를 자유롭게 제출해주세요.

## 라이선스

ReducerKit은 MIT 라이선스로 제공됩니다. 자세한 내용은 LICENSE 파일을 참조하세요.

## 감사의 글

- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)에서 영감을 받음

