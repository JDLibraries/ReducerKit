# @ObservableState 매크로

## 개요

`@ObservableState`는 State struct에 KeyPath 기반 세밀한 관찰 기능을 자동으로 추가하는 매크로입니다.

이 매크로를 사용하면:
1. `ObservableStateProtocol` 준수 코드를 자동 생성
2. 모든 저장 프로퍼티의 KeyPath 목록 생성
3. 프로퍼티별 변경 감지 메서드 생성

## 전체 코드

```swift
@attached(extension, conformances: ObservableStateProtocol, names: named(_$observableKeyPaths), named(hasChanged(_:from:to:)))
public macro ObservableState() = #externalMacro(
    module: "ReducerKitMacros",
    type: "ObservableStateMacro"
)
```

## 매크로란?

**매크로**는 컴파일 시점에 코드를 자동으로 생성하는 Swift의 기능입니다.

### 매크로가 없다면?

```swift
// 개발자가 직접 작성해야 하는 코드
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
}

// ObservableStateProtocol 준수 코드도 직접 작성
extension CounterState: ObservableStateProtocol {
    static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [\Self.count, \Self.isLoading]
    }

    static func hasChanged(
        _ keyPath: PartialKeyPath<Self>,
        from oldValue: Self,
        to newValue: Self
    ) -> Bool {
        switch keyPath {
        case \Self.count:
            return oldValue.count != newValue.count
        case \Self.isLoading:
            return oldValue.isLoading != newValue.isLoading
        default:
            return false
        }
    }
}

// 프로퍼티를 추가하면?
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var message: String = ""  // ← 새 프로퍼티
}

// extension도 수동으로 업데이트 필요
extension CounterState: ObservableStateProtocol {
    static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [\Self.count, \Self.isLoading, \Self.message]  // ← 추가
    }

    static func hasChanged(...) -> Bool {
        switch keyPath {
        case \Self.count: ...
        case \Self.isLoading: ...
        case \Self.message:  // ← 추가
            return oldValue.message != newValue.message
        default:
            return false
        }
    }
}
```

### 매크로 사용

```swift
// 매크로로 간단하게
@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
}

// extension은 매크로가 자동 생성!
// 프로퍼티 추가해도 자동으로 반영됨
```

## 코드 상세 분석

### 1. @attached 어트리뷰트

```swift
@attached(extension, conformances: ObservableStateProtocol, names: named(_$observableKeyPaths), named(hasChanged(_:from:to:)))
```

매크로가 어떻게 코드를 생성할지 지정합니다.

#### `@attached`
이 매크로가 "부착형(attached)" 매크로임을 나타냅니다.

**Swift 매크로 종류:**
1. **Attached 매크로**: 선언에 부착하여 코드 생성
   - `@attached(extension)`: extension 생성
   - `@attached(member)`: 멤버 추가
   - `@attached(peer)`: 동일 레벨에 선언 추가

2. **Freestanding 매크로**: 독립적으로 사용
   - `#function`: 현재 함수 이름
   - `#file`: 현재 파일 경로

#### `extension`
이 매크로가 extension을 생성함을 명시합니다.

```swift
@ObservableState  // ← 이것을 적용하면
struct MyState { }

// ↓ extension이 생성됨
extension MyState: ObservableStateProtocol {
    // 생성된 코드...
}
```

#### `conformances: ObservableStateProtocol`
생성된 extension이 어떤 프로토콜을 준수하는지 명시합니다.

```swift
// 매크로가 생성하는 코드:
extension MyState: ObservableStateProtocol {
    // ↑ 이 프로토콜 준수
}
```

#### `names: named(...)`
매크로가 생성하는 선언의 이름을 명시합니다.

```swift
names: named(_$observableKeyPaths), named(hasChanged(_:from:to:))
```

- `named(_$observableKeyPaths)`: `_$observableKeyPaths`라는 이름의 선언 생성
- `named(hasChanged(_:from:to:))`: `hasChanged(_:from:to:)` 메서드 생성

**왜 이름을 명시하나?**
- 컴파일러가 어떤 이름이 생성될지 미리 알아야 함
- 이름 충돌 검사
- 코드 자동완성 지원

### 2. macro 선언

```swift
public macro ObservableState() = #externalMacro(
    module: "ReducerKitMacros",
    type: "ObservableStateMacro"
)
```

#### `public macro ObservableState()`
- `public`: 다른 모듈에서 사용 가능
- `macro`: 매크로 선언
- `ObservableState`: 매크로 이름
- `()`: 파라미터 없음

#### `#externalMacro`
매크로의 실제 구현이 외부 모듈에 있음을 나타냅니다.

```swift
#externalMacro(
    module: "ReducerKitMacros",     // 구현이 있는 모듈
    type: "ObservableStateMacro"    // 구현 타입 (struct/class 이름)
)
```

**왜 external인가?**
- 매크로 구현은 컴파일러 플러그인으로 실행됨
- 별도의 실행 파일로 빌드됨
- 보안과 샌드박싱을 위해 분리

## 매크로 사용법

### 기본 사용

```swift
@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var message: String?
}
```

### 생성되는 코드 확인

Xcode에서 매크로가 생성한 코드를 볼 수 있습니다:

1. `@ObservableState`에 우클릭
2. "Expand Macro" 선택

```swift
// 확장된 코드
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var message: String?
}

extension CounterState: ObservableStateProtocol {
    public static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [\Self.count, \Self.isLoading, \Self.message]
    }

    public static func hasChanged(
        _ keyPath: PartialKeyPath<Self>,
        from oldValue: Self,
        to newValue: Self
    ) -> Bool {
        switch keyPath {
        case \Self.count:
            return oldValue.count != newValue.count
        case \Self.isLoading:
            return oldValue.isLoading != newValue.isLoading
        case \Self.message:
            return oldValue.message != newValue.message
        default:
            return false
        }
    }
}
```

## 매크로가 처리하는 것

### 저장 프로퍼티만 포함

```swift
@ObservableState
struct MyState: Equatable {
    var storedProperty: Int = 0  // ✅ 포함됨

    var computedProperty: String {  // ❌ 제외됨
        "Computed"
    }

    static var staticProperty: Int = 0  // ❌ 제외됨
}

// 생성되는 코드
extension MyState: ObservableStateProtocol {
    static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [\Self.storedProperty]  // 저장 프로퍼티만!
    }
    // ...
}
```

### 다양한 타입 지원

```swift
@ObservableState
struct TodoState: Equatable {
    var todos: [Todo] = []           // 배열
    var filter: Filter = .all        // enum
    var isLoading: Bool = false      // Bool
    var error: Error?                // Optional
    var date: Date = Date()          // 다른 타입들
}

// 모든 저장 프로퍼티가 KeyPath 목록에 포함됨
```

### 중첩된 State

```swift
@ObservableState
struct AppState: Equatable {
    var counter: CounterState = CounterState()
    var todo: TodoState = TodoState()
}

@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
}

@ObservableState
struct TodoState: Equatable {
    var items: [String] = []
}

// 각 State가 독립적으로 관찰 가능
```

## 매크로 제약사항

### 1. struct에만 적용 가능

```swift
// ✅ 올바른 사용
@ObservableState
struct MyState: Equatable { }

// ❌ class에는 사용 불가
@ObservableState  // 컴파일 에러!
class MyState: Equatable { }

// ❌ enum에는 사용 불가
@ObservableState  // 컴파일 에러!
enum MyState { }
```

### 2. 최소 하나의 저장 프로퍼티 필요

```swift
// ❌ 저장 프로퍼티가 없음
@ObservableState  // 컴파일 에러!
struct EmptyState: Equatable { }

// ❌ computed 프로퍼티만 있음
@ObservableState  // 컴파일 에러!
struct ComputedOnlyState: Equatable {
    var value: Int { 42 }
}

// ✅ 저장 프로퍼티 있음
@ObservableState
struct ValidState: Equatable {
    var value: Int = 0
}
```

### 3. Equatable 준수 필요

```swift
// ❌ Equatable 준수 안 함
@ObservableState
struct MyState { }  // 컴파일 에러!

// ✅ Equatable 준수
@ObservableState
struct MyState: Equatable { }
```

## 실전 예시

### 예시 1: 간단한 카운터

```swift
@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
}

struct CounterReducer: Reducer {
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        }
    }
}

struct CounterView: View {
    @State var store = Store(
        initialState: CounterState(),
        reducer: CounterReducer()
    )

    var body: some View {
        VStack {
            Text("Count: \(store.count)")  // 세밀한 관찰!
            Button("Increment") {
                store.send(.increment)
            }
        }
    }
}
```

### 예시 2: 복잡한 Todo 앱

```swift
@ObservableState
struct TodoState: Equatable {
    var todos: [Todo] = []
    var filter: Filter = .all
    var editingId: UUID?
    var isLoading: Bool = false
    var error: String?
}

enum Filter: Equatable {
    case all, active, completed
}

struct TodoView: View {
    @State var store: Store<TodoReducer>

    var body: some View {
        VStack {
            // filter만 사용 → filter 변경 시에만 업데이트
            FilterPicker(selected: store.filter) { filter in
                store.send(.filterChanged(filter))
            }

            // todos만 사용 → todos 변경 시에만 업데이트
            List(store.todos) { todo in
                TodoRow(todo: todo)
            }

            // isLoading만 사용 → isLoading 변경 시에만 업데이트
            if store.isLoading {
                ProgressView()
            }

            // error만 사용 → error 변경 시에만 업데이트
            if let error = store.error {
                Text(error).foregroundColor(.red)
            }
        }
    }
}
```

### 예시 3: 중첩된 State 조합

```swift
@ObservableState
struct AppState: Equatable {
    var user: UserState = UserState()
    var settings: SettingsState = SettingsState()
    var navigation: NavigationState = NavigationState()
}

@ObservableState
struct UserState: Equatable {
    var profile: Profile?
    var isLoggedIn: Bool = false
}

@ObservableState
struct SettingsState: Equatable {
    var isDarkMode: Bool = false
    var notifications: Bool = true
}

@ObservableState
struct NavigationState: Equatable {
    var selectedTab: Tab = .home
    var path: [Route] = []
}

struct AppView: View {
    @State var store: Store<AppReducer>

    var body: some View {
        TabView(selection: $store.navigation.selectedTab) {
            // navigation.selectedTab만 관찰

            HomeView(store: store)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            SettingsView(store: store)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(Tab.settings)
        }
    }
}
```

## 매크로 vs 수동 구현 비교

### 장점

1. **자동화**: extension 코드를 자동 생성
2. **타입 안전**: 컴파일 타임에 검증
3. **유지보수**: 프로퍼티 추가/제거 시 자동 반영
4. **실수 방지**: 수동 작성 시 발생할 수 있는 오타, 누락 방지

### 단점

1. **학습 곡선**: 매크로 개념 이해 필요
2. **디버깅**: 생성된 코드를 직접 볼 수 없음 (Expand Macro로 확인 가능)
3. **컴파일 시간**: 매크로 실행으로 약간의 시간 추가

## Swift 매크로 시스템

### 매크로 종류

#### 1. Attached 매크로
선언에 부착하여 코드 추가:

```swift
// Extension 매크로
@attached(extension)
macro AddProtocol()

// Member 매크로
@attached(member)
macro AddMember()

// Peer 매크로
@attached(peer)
macro AddPeer()
```

#### 2. Freestanding 매크로
독립적으로 사용:

```swift
// Expression 매크로
#stringify(1 + 2)  // ("1 + 2", 3)

// Declaration 매크로
#function  // 현재 함수 이름
```

### @ObservableState는 Extension 매크로

```swift
@attached(extension, ...)  // ← Extension 매크로
public macro ObservableState()
```

- struct 선언에 부착
- extension을 생성하여 프로토콜 준수 코드 추가

## 핵심 개념 정리

### 1. 매크로
컴파일 시점에 코드를 자동 생성하는 기능

### 2. @attached(extension)
대상 타입에 extension을 추가하는 매크로 종류

### 3. #externalMacro
매크로 구현이 외부 모듈에 있음을 나타냄

### 4. 생성 코드
ObservableStateProtocol 준수를 위한 _$observableKeyPaths와 hasChanged 메서드

