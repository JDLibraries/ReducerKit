# Getting Started

ReducerKit을 시작하는 방법을 배워봅시다.

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
https://github.com/JDLibraries/ReducerKit
```
3. 사용할 버전 선택

또는 `Package.swift` 파일에 직접 추가:

```swift
dependencies: [
    .package(url: "https://github.com/JDLibraries/ReducerKit", from: "1.0.0")
]
```

## 기본 예제

### 1. State 정의

```swift
import ReducerKit

@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
}
```

### 2. Action 정의

```swift
enum CounterAction: Sendable {
    case increment
    case decrement
}
```

### 3. Reducer 구현

```swift
struct CounterReducer: Reducer {
    typealias State = CounterState
    typealias Action = CounterAction

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
```

### 4. View 생성

```swift
import SwiftUI

struct ContentView: View {
    @State private var store = Store(
        initialState: CounterState(),
        reducer: CounterReducer()
    )

    var body: some View {
        VStack(spacing: 40) {
            Text("\(store.count)")
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
        }
        .padding()
    }
}
```

## 핵심 포인트

1. **@ObservableState**: State에 항상 적용하세요
2. **dynamicMemberLookup**: View에서 `store.count` 형태로 접근하세요 (필수!)
3. **Reducer**: 순수 함수로 유지하고, 상태만 수정하세요
4. **Effect**: 모든 비동기 작업은 Effect를 통해 수행하세요

## 다음 단계

자세한 내용은 다음을 참조하세요:

- <doc:Store>: Store의 내부 구조와 동작 원리
- <doc:Reducer>: Reducer 작성 방법
- <doc:Effect>: 부수 효과 처리
- <doc:ObservableState>: @ObservableState 매크로 사용법
