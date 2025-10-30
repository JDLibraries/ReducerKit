# ObservableStateProtocol

## 개요

`ObservableStateProtocol`은 **KeyPath 기반의 세밀한 관찰**을 지원하기 위한 프로토콜입니다.

이 프로토콜을 준수하는 State는:
1. 어떤 프로퍼티들이 관찰 가능한지 (KeyPath 목록)
2. 특정 프로퍼티가 변경되었는지 확인하는 방법

을 제공해야 합니다.

## 전체 코드

```swift
public protocol ObservableStateProtocol: Equatable, Sendable {
    static var _$observableKeyPaths: [PartialKeyPath<Self>] { get }

    static func hasChanged(
        _ keyPath: PartialKeyPath<Self>,
        from oldValue: Self,
        to newValue: Self
    ) -> Bool
}
```

## 왜 이 프로토콜이 필요한가?

### 문제: SwiftUI의 전체 상태 관찰

일반적인 `@ObservableObject`나 `@StateObject`를 사용하면:

```swift
class Store: ObservableObject {
    @Published var state: State
}

struct State: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var text: String = ""
}

struct ContentView: View {
    @StateObject var store: Store

    var body: some View {
        VStack {
            Text("\(store.state.count)")  // count만 사용
        }
    }
}
```

**문제점**: `count`만 사용하지만, `isLoading`이나 `text`가 변경되어도 View가 다시 그려집니다!

### 해결: 프로퍼티별 관찰

ObservableStateProtocol을 사용하면:

```swift
@ObservableState  // ← 매크로가 프로토콜 준수 코드 생성
struct State: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
    var text: String = ""
}

struct ContentView: View {
    @State var store: Store<CounterReducer>

    var body: some View {
        VStack {
            Text("\(store.count)")  // count만 관찰
            // isLoading이나 text가 변해도 다시 그려지지 않음!
        }
    }
}
```

## 코드 상세 분석

### 1. 프로토콜 선언

```swift
public protocol ObservableStateProtocol: Equatable, Sendable {
```

#### 프로토콜 상속:
- `Equatable`: State를 비교할 수 있어야 함
  - 변경 감지를 위해 필수
- `Sendable`: 스레드 간 안전하게 전달 가능해야 함
  - Swift Concurrency 지원을 위해 필수

### 2. _$observableKeyPaths 프로퍼티

```swift
static var _$observableKeyPaths: [PartialKeyPath<Self>] { get }
```

State의 모든 관찰 가능한 프로퍼티의 KeyPath 목록을 반환합니다.

#### 각 부분 설명:

##### `static`
타입 레벨 프로퍼티 (인스턴스가 아닌 타입 자체에 속함):

```swift
struct Example {
    static let typeProperty = "타입에 속함"
    let instanceProperty = "인스턴스에 속함"
}

print(Example.typeProperty)  // "타입에 속함"
// print(Example.instanceProperty)  // 에러! 인스턴스 필요

let instance = Example()
print(instance.instanceProperty)  // "인스턴스에 속함"
```

##### `[PartialKeyPath<Self>]`
배열의 각 요소는 `PartialKeyPath<Self>` 타입입니다.

**PartialKeyPath란?**

KeyPath의 한 종류로, 타입은 알지만 값 타입을 모르는 KeyPath입니다.

```swift
struct Person {
    var name: String
    var age: Int
}

// KeyPath - 타입과 값 타입을 모두 알고 있음
let nameKeyPath: KeyPath<Person, String> = \Person.name

// PartialKeyPath - 타입만 알고 값 타입은 모름
let unknownKeyPath: PartialKeyPath<Person> = \Person.name
// 또는
let unknownKeyPath: PartialKeyPath<Person> = \Person.age

// 사용 차이
let person = Person(name: "Alice", age: 30)

// KeyPath - 값 타입을 알므로 직접 접근 가능
let name: String = person[keyPath: nameKeyPath]  // "Alice"

// PartialKeyPath - 값 타입을 모르므로 타입 캐스팅 필요
if let value = person[keyPath: unknownKeyPath] as? String {
    print(value)
}
```

**왜 PartialKeyPath를 사용하나?**

State의 프로퍼티들은 서로 다른 타입을 가질 수 있습니다:

```swift
struct State {
    var count: Int        // Int 타입
    var isLoading: Bool   // Bool 타입
    var text: String      // String 타입
}

// 이 세 가지를 한 배열에 담으려면?
// KeyPath<State, Int>와 KeyPath<State, Bool>은 다른 타입!

// PartialKeyPath를 사용하면 한 배열에 담을 수 있음
let keyPaths: [PartialKeyPath<State>] = [
    \State.count,      // KeyPath<State, Int> → PartialKeyPath<State>
    \State.isLoading,  // KeyPath<State, Bool> → PartialKeyPath<State>
    \State.text        // KeyPath<State, String> → PartialKeyPath<State>
]
```

#### 실제 사용 예시:

```swift
@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
}

// 매크로가 자동 생성한 코드:
extension CounterState: ObservableStateProtocol {
    static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [
            \Self.count,      // KeyPath를 배열로 반환
            \Self.isLoading
        ]
    }
    // ...
}

// Store에서 사용:
for keyPath in State._$observableKeyPaths {
    // 모든 프로퍼티에 대해 초기화 작업
    _keyPathVersions[keyPath] = 0
}
```

### 3. hasChanged 메서드

```swift
static func hasChanged(
    _ keyPath: PartialKeyPath<Self>,
    from oldValue: Self,
    to newValue: Self
) -> Bool
```

특정 KeyPath의 값이 두 상태 사이에서 변경되었는지 확인합니다.

#### 파라미터 설명:

##### `_ keyPath: PartialKeyPath<Self>`
- `_`: 외부 파라미터 레이블 생략
- 확인할 프로퍼티의 KeyPath

##### `from oldValue: Self`
- 이전 상태

##### `to newValue: Self`
- 새로운 상태

##### `-> Bool`
- 값이 변경되었으면 `true`, 아니면 `false`

#### 실제 사용 예시:

```swift
@ObservableState
struct CounterState: Equatable {
    var count: Int = 0
    var isLoading: Bool = false
}

// 매크로가 자동 생성한 코드:
extension CounterState: ObservableStateProtocol {
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

// Store에서 사용:
let oldState = State(count: 0, isLoading: false)
let newState = State(count: 1, isLoading: false)

for keyPath in State._$observableKeyPaths {
    if State.hasChanged(keyPath, from: oldState, to: newState) {
        // 이 KeyPath의 버전 증가
        observableVersions[AnyHashable(keyPath)]?.value += 1
    }
}
// count만 변경되었으므로 \State.count만 버전이 증가
```

## KeyPath 완전 정리

KeyPath는 "프로퍼티의 경로"를 타입 안전하게 표현하는 방법입니다.

### KeyPath의 종류

```swift
struct Address {
    var street: String
    var city: String
}

struct Person {
    var name: String
    var age: Int
    var address: Address
}

// 1. KeyPath<Root, Value> - 읽기 전용
let nameKeyPath: KeyPath<Person, String> = \Person.name
let person = Person(name: "Alice", age: 30, address: Address(street: "Main St", city: "NY"))
let name = person[keyPath: nameKeyPath]  // "Alice"

// 2. WritableKeyPath<Root, Value> - 읽기/쓰기 가능
let ageKeyPath: WritableKeyPath<Person, Int> = \Person.age
var mutablePerson = person
mutablePerson[keyPath: ageKeyPath] = 31

// 3. ReferenceWritableKeyPath<Root, Value> - 클래스의 프로퍼티
class MutablePerson {
    var name: String = ""
}
let mutableNameKeyPath: ReferenceWritableKeyPath<MutablePerson, String> = \MutablePerson.name

// 4. PartialKeyPath<Root> - 값 타입을 모름
let unknownKeyPath: PartialKeyPath<Person> = \Person.name  // String인지 모름

// 5. AnyKeyPath - Root 타입도 값 타입도 모름
let totallyUnknownKeyPath: AnyKeyPath = \Person.name
```

### KeyPath 체이닝

```swift
struct Person {
    var address: Address
}

struct Address {
    var city: String
}

// 중첩된 프로퍼티 접근
let cityKeyPath = \Person.address.city  // KeyPath<Person, String>

let person = Person(address: Address(city: "Seoul"))
let city = person[keyPath: cityKeyPath]  // "Seoul"
```

### KeyPath를 왜 사용하나?

#### 1. 타입 안전성
```swift
// 문자열로 프로퍼티 접근 (타입 안전하지 않음)
let value = object.value(forKey: "name")  // Any? 반환

// KeyPath 사용 (타입 안전)
let value = person[keyPath: \Person.name]  // String 반환
```

#### 2. 리팩토링 안전
```swift
// 문자열은 리팩토링 시 업데이트되지 않음
let key = "name"  // Person의 name을 userName으로 변경해도 에러 없음

// KeyPath는 자동으로 업데이트
let keyPath = \Person.name  // name → userName 변경 시 컴파일 에러
```

#### 3. 고차 함수와 조합
```swift
struct Person {
    var name: String
    var age: Int
}

let people = [
    Person(name: "Alice", age: 30),
    Person(name: "Bob", age: 25)
]

// KeyPath를 사용한 정렬
let sortedByAge = people.sorted(by: \.age)  // age로 정렬
let sortedByName = people.sorted(by: \.name)  // name으로 정렬
```

## 매크로가 생성하는 코드 전체 예시

```swift
// 개발자가 작성하는 코드
@ObservableState
struct TodoState: Equatable {
    var todos: [Todo] = []
    var filter: Filter = .all
    var isLoading: Bool = false
}

// 매크로가 자동 생성하는 코드
extension TodoState: ObservableStateProtocol {
    // 1. KeyPath 목록
    public static var _$observableKeyPaths: [PartialKeyPath<Self>] {
        [
            \Self.todos,
            \Self.filter,
            \Self.isLoading
        ]
    }

    // 2. 변경 감지 메서드
    public static func hasChanged(
        _ keyPath: PartialKeyPath<Self>,
        from oldValue: Self,
        to newValue: Self
    ) -> Bool {
        switch keyPath {
        case \Self.todos:
            return oldValue.todos != newValue.todos

        case \Self.filter:
            return oldValue.filter != newValue.filter

        case \Self.isLoading:
            return oldValue.isLoading != newValue.isLoading

        default:
            return false
        }
    }
}
```

## Store에서 어떻게 사용되나?

Store는 이 프로토콜을 사용하여 프로퍼티별 관찰을 구현합니다:

```swift
// Store.swift 초기화 (line 69-74)
public init(initialState: State, reducer: R) {
    self._state = initialState
    self.reduce = reducer.reduce(into:action:)

    // 모든 KeyPath의 초기 버전 설정
    for keyPath in State._$observableKeyPaths {  // ← 프로토콜 사용
        _keyPathVersions[keyPath] = 0
        observableVersions[AnyHashable(keyPath)] = ObservableVersion()
    }
}

// Store.swift 버전 업데이트 (line 129-139)
private func updateVersions(from oldState: State, to newState: State) {
    for keyPath in State._$observableKeyPaths {  // ← 프로토콜 사용
        // hasChanged로 변경 확인
        if State.hasChanged(keyPath, from: oldState, to: newState) {
            // 변경된 KeyPath만 버전 증가
            if let version = observableVersions[AnyHashable(keyPath)] {
                version.value += 1
            }
        }
    }
}
```

## 핵심 개념 정리

### 1. PartialKeyPath

값 타입을 모르는 KeyPath로, 다양한 타입의 프로퍼티를 한 배열에 저장할 수 있게 합니다.

### 2. static 프로퍼티/메서드

타입 자체에 속하는 프로퍼티/메서드로, 인스턴스 없이 접근 가능합니다.

### 3. 프로토콜 제약

`Equatable`과 `Sendable` 제약으로 비교 가능성과 스레드 안전성을 보장합니다.

## 왜 이렇게 설계했나?

### 1. KeyPath 목록 제공
Store가 어떤 프로퍼티들을 관찰해야 하는지 알 수 있음

### 2. 변경 감지 메서드
Equatable만으로는 "어느 프로퍼티가" 변경되었는지 알 수 없음
hasChanged로 프로퍼티별 변경 감지 가능

### 3. static 메서드
인스턴스 메서드로는 oldValue와 newValue를 동시에 비교하기 어려움
static 메서드로 두 값을 받아 비교

