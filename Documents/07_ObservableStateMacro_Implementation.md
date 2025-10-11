# ObservableStateMacro 구현

## 개요

`ObservableStateMacro`는 `@ObservableState` 매크로의 실제 구현으로, SwiftSyntax를 사용하여 코드를 분석하고 생성합니다.

이 문서에서는 매크로가 어떻게 동작하는지 코드 한 줄 한 줄 자세히 설명합니다.

## 전체 코드 구조

```swift
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ObservableStateMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // 구현...
    }
}
```

## SwiftSyntax란?

**SwiftSyntax**는 Swift 코드를 구조화된 형태로 표현하고 조작할 수 있는 라이브러리입니다.

### Syntax Tree (구문 트리)

코드를 트리 구조로 표현합니다:

```swift
struct Counter {
    var count: Int = 0
}
```

이 코드의 Syntax Tree:

```
StructDeclSyntax
├─ name: "Counter"
└─ memberBlock:
    └─ members:
        └─ VariableDeclSyntax
            ├─ keyword: "var"
            ├─ bindings:
            │   └─ pattern: "count"
            │   └─ typeAnnotation: "Int"
            │   └─ initializer: "0"
```

### SwiftSyntax의 주요 타입

```swift
// 선언 (Declaration) 타입들
StructDeclSyntax       // struct 선언
ClassDeclSyntax        // class 선언
VariableDeclSyntax     // 변수/프로퍼티 선언
FunctionDeclSyntax     // 함수 선언

// 타입 (Type) 타입들
TypeSyntax             // 모든 타입의 프로토콜
TypeSyntaxProtocol     // 타입을 나타내는 프로토콜

// 표현식 (Expression) 타입들
ExprSyntax             // 모든 표현식

// 문법 그룹
DeclGroupSyntax        // struct, class, enum 등을 포함하는 프로토콜
```

## 코드 상세 분석

### 1. ExtensionMacro 프로토콜

```swift
public struct ObservableStateMacro: ExtensionMacro {
```

#### `ExtensionMacro` 프로토콜

extension을 생성하는 매크로가 준수해야 하는 프로토콜입니다.

```swift
public protocol ExtensionMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax]
}
```

### 2. expansion 메서드 시그니처

```swift
public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
) throws -> [ExtensionDeclSyntax]
```

#### 파라미터 설명:

##### `of node: AttributeSyntax`
매크로 자체를 나타냅니다.

```swift
@ObservableState  // ← 이것이 AttributeSyntax
struct MyState { }

// node는 "@ObservableState"를 표현하는 객체
```

##### `attachedTo declaration: some DeclGroupSyntax`
매크로가 적용된 선언(struct, class, enum 등)입니다.

```swift
@ObservableState
struct MyState {    // ← 이것이 DeclGroupSyntax
    var count: Int
}

// declaration은 "struct MyState { ... }"를 표현하는 객체
```

##### `providingExtensionsOf type: some TypeSyntaxProtocol`
확장할 타입의 이름입니다.

```swift
struct MyState { }  // ← "MyState"가 type

// type은 "MyState"라는 타입 이름을 표현하는 객체
```

##### `conformingTo protocols: [TypeSyntax]`
준수해야 하는 프로토콜 목록입니다.

```swift
// @ObservableState 매크로 정의에서:
@attached(extension, conformances: ObservableStateProtocol, ...)
                                    // ↑ 이것이 protocols 배열에 포함됨
```

##### `in context: some MacroExpansionContext`
매크로 확장을 위한 컨텍스트로, 에러 발생이나 고유 이름 생성 등에 사용됩니다.

##### `-> [ExtensionDeclSyntax]`
생성할 extension들의 배열을 반환합니다.

```swift
// 반환값 예시:
[
    extension MyState: ObservableStateProtocol {
        static var _$observableKeyPaths: ...
        static func hasChanged(...) -> Bool { ... }
    }
]
```

### 3. struct인지 확인

```swift
// 1. struct인지 확인
guard let structDecl = declaration.as(StructDeclSyntax.self) else {
    throw MacroError.notAStruct
}
```

#### `declaration.as(StructDeclSyntax.self)`

타입 캐스팅을 시도합니다.

```swift
// DeclGroupSyntax는 여러 타입을 포함하는 프로토콜:
// - StructDeclSyntax (struct)
// - ClassDeclSyntax (class)
// - EnumDeclSyntax (enum)
// 등등...

let declaration: DeclGroupSyntax = ...

// struct로 캐스팅 시도
if let structDecl = declaration.as(StructDeclSyntax.self) {
    // struct인 경우
    print(structDecl.name)  // struct 이름 접근 가능
} else {
    // struct가 아닌 경우 (class, enum 등)
}
```

#### 왜 struct만 허용하나?

- State는 값 타입(value type)이어야 함
- Equatable 구현이 간단함
- 불변성(immutability) 보장

### 4. 저장 프로퍼티 찾기

```swift
// 2. 저장 프로퍼티들 찾기
let properties = structDecl.memberBlock.members
    .compactMap { $0.decl.as(VariableDeclSyntax.self) }
    .filter { $0.isStoredProperty }
```

#### `structDecl.memberBlock.members`

struct의 모든 멤버를 가져옵니다.

```swift
struct MyState {
    var count: Int = 0          // ← 멤버 1
    var isLoading: Bool = false // ← 멤버 2
    func reset() { }            // ← 멤버 3
}

// memberBlock.members는 이 세 멤버를 모두 포함
```

#### `.compactMap { $0.decl.as(VariableDeclSyntax.self) }`

변수/프로퍼티 선언만 추출합니다.

```swift
// 각 멤버는 MemberBlockItemSyntax 타입
struct MemberBlockItemSyntax {
    var decl: DeclSyntax  // 실제 선언 (변수, 함수 등)
}

// decl을 VariableDeclSyntax로 캐스팅
members.compactMap { member in
    member.decl.as(VariableDeclSyntax.self)
}
// 결과: [count, isLoading] (함수는 제외됨)
```

**compactMap이란?**

map + filter(nil 제거):

```swift
let numbers = [1, 2, 3, 4, 5]

// map: 모든 요소 변환
numbers.map { $0 * 2 }  // [2, 4, 6, 8, 10]

// compactMap: 변환하되 nil은 제거
numbers.compactMap { $0 % 2 == 0 ? $0 : nil }  // [2, 4]

// 타입 캐스팅에 유용
let values: [Any] = [1, "hello", 2, "world"]
values.compactMap { $0 as? Int }  // [1, 2]
```

#### `.filter { $0.isStoredProperty }`

저장 프로퍼티만 필터링합니다.

```swift
struct MyState {
    var stored: Int = 0       // ✅ 저장 프로퍼티

    var computed: Int {       // ❌ 계산 프로퍼티
        stored * 2
    }

    static var static: Int = 0  // ❌ static 프로퍼티
}

// isStoredProperty는 Helper Extension에서 정의됨 (아래 참조)
```

### 5. Helper Extension: isStoredProperty

```swift
extension VariableDeclSyntax {
    /// 저장 프로퍼티인지 확인
    var isStoredProperty: Bool {
        // getter/setter가 없고, willSet/didSet도 없으면 저장 프로퍼티
        if bindings.first?.accessorBlock != nil {
            return false
        }
        // static이나 computed가 아니면 저장 프로퍼티
        return modifiers.allSatisfy { modifier in
            !["static", "class"].contains(modifier.name.text)
        }
    }
}
```

#### `bindings.first?.accessorBlock`

프로퍼티의 accessor(getter/setter 등)를 확인합니다.

```swift
// 저장 프로퍼티 (accessor 없음)
var count: Int = 0
// bindings.first?.accessorBlock == nil

// 계산 프로퍼티 (getter 있음)
var doubled: Int {
    count * 2
}
// bindings.first?.accessorBlock != nil (getter 있음)

// 프로퍼티 관찰자 (willSet/didSet)
var count: Int = 0 {
    didSet { print("changed") }
}
// bindings.first?.accessorBlock != nil (didSet 있음)
```

**bindings란?**

하나의 var/let 선언에 여러 변수가 올 수 있습니다:

```swift
var a = 1, b = 2, c = 3  // 3개의 binding
//  ↑     ↑     ↑
//  binding1  binding2  binding3

// 일반적으로는 하나만 사용
var count: Int = 0  // 1개의 binding
```

#### `modifiers.allSatisfy { ... }`

모든 modifier가 조건을 만족하는지 확인합니다.

```swift
// static 프로퍼티
static var count: Int = 0
// modifiers: ["static"]
// allSatisfy { !["static", "class"].contains($0) } → false

// 일반 프로퍼티
var count: Int = 0
// modifiers: []
// allSatisfy { !["static", "class"].contains($0) } → true
```

**allSatisfy란?**

모든 요소가 조건을 만족하는지 확인:

```swift
let numbers = [2, 4, 6, 8]
numbers.allSatisfy { $0 % 2 == 0 }  // true (모두 짝수)

let mixed = [2, 3, 4]
mixed.allSatisfy { $0 % 2 == 0 }  // false (3은 홀수)

// 빈 배열은 항상 true
[].allSatisfy { $0 > 100 }  // true (vacuous truth)
```

### 6. 빈 프로퍼티 확인

```swift
guard !properties.isEmpty else {
    throw MacroError.noStoredProperties
}
```

저장 프로퍼티가 하나도 없으면 에러를 발생시킵니다.

### 7. KeyPath 배열 생성

```swift
// 3. KeyPath 배열 생성
let keyPathsArray = properties.map { property in
    let name = property.bindings.first!.pattern
    return #"\Self.\#(name)"#
}.joined(separator: ", ")
```

#### 각 부분 설명:

##### `property.bindings.first!.pattern`

프로퍼티 이름을 추출합니다.

```swift
var count: Int = 0
//  ↑
//  pattern (프로퍼티 이름)

var (x, y): (Int, Int) = (1, 2)
//  ↑
//  pattern (튜플 패턴)

// 일반적으로는 단일 이름
```

##### `#"\Self.\#(name)"#`

문자열 보간(interpolation)을 사용하여 KeyPath를 생성합니다.

```swift
let name = "count"
let keyPath = #"\Self.\#(name)"#
// 결과: "\Self.count"
```

**# 문자열 리터럴이란?**

특수 문자를 이스케이프 없이 사용할 수 있는 문자열:

```swift
// 일반 문자열
let str1 = "Hello \"World\""  // 따옴표 이스케이프 필요
let str2 = "Path: C:\\Users"  // 백슬래시 이스케이프 필요

// # 문자열 (raw string)
let str3 = #"Hello "World""#  // 이스케이프 불필요
let str4 = #"Path: C:\Users"#  // 백슬래시 그대로

// 보간은 \#() 사용
let name = "Alice"
let str5 = #"Hello \#(name)"#  // "Hello Alice"
```

매크로에서는 백슬래시(\)를 많이 사용하므로 # 문자열이 유용합니다:

```swift
// # 없이
"\\Self.\(name)"  // 백슬래시 이스케이프 필요

// # 사용
#"\Self.\#(name)"#  // 더 읽기 쉬움
```

##### `.joined(separator: ", ")`

배열의 요소들을 쉼표로 연결합니다.

```swift
let names = ["count", "isLoading", "text"]
let keyPaths = names.map { #"\Self.\#($0)"# }
// ["\Self.count", "\Self.isLoading", "\Self.text"]

let joined = keyPaths.joined(separator: ", ")
// "\Self.count, \Self.isLoading, \Self.text"
```

#### 전체 예시:

```swift
struct State {
    var count: Int
    var isLoading: Bool
}

// properties: [count, isLoading]

let keyPathsArray = properties.map { property in
    let name = property.bindings.first!.pattern  // "count", "isLoading"
    return #"\Self.\#(name)"#  // "\Self.count", "\Self.isLoading"
}.joined(separator: ", ")

// 결과: "\Self.count, \Self.isLoading"
```

### 8. hasChanged switch cases 생성

```swift
// 4. hasChanged switch cases 생성
let switchCases = properties.map { property in
    let name = property.bindings.first!.pattern
    return """
            case \\Self.\(name):
                return oldValue.\(name) != newValue.\(name)
    """
}.joined(separator: "\n")
```

#### 멀티라인 문자열

```swift
let name = "count"
let caseCode = """
        case \\Self.\(name):
            return oldValue.\(name) != newValue.\(name)
"""

// 결과:
//         case \Self.count:
//             return oldValue.count != newValue.count
```

**멀티라인 문자열(""")의 들여쓰기:**

```swift
// 닫는 """의 위치가 기준선
let code = """
    line 1
    line 2
    """
// "    line 1\n    line 2"

let code2 = """
line 1
line 2
"""
// "line 1\nline 2"
```

#### 전체 예시:

```swift
struct State {
    var count: Int
    var isLoading: Bool
}

let switchCases = properties.map { property in
    let name = property.bindings.first!.pattern
    return """
            case \\Self.\(name):
                return oldValue.\(name) != newValue.\(name)
    """
}.joined(separator: "\n")

// 결과:
//         case \Self.count:
//             return oldValue.count != newValue.count
//         case \Self.isLoading:
//             return oldValue.isLoading != newValue.isLoading
```

### 9. Extension 생성

```swift
// 5. Extension 생성
let extensionDecl: DeclSyntax = """
    extension \(type.trimmed): ObservableStateProtocol {
        public static var _$observableKeyPaths: [PartialKeyPath<Self>] {
            [\(raw: keyPathsArray)]
        }

        public static func hasChanged(
            _ keyPath: PartialKeyPath<Self>,
            from oldValue: Self,
            to newValue: Self
        ) -> Bool {
            switch keyPath {
            \(raw: switchCases)
            default:
                return false
            }
        }
    }
    """
```

#### `DeclSyntax`

선언을 나타내는 Syntax 타입입니다.

```swift
// DeclSyntax는 모든 선언의 프로토콜:
// - ExtensionDeclSyntax (extension)
// - StructDeclSyntax (struct)
// - FunctionDeclSyntax (func)
// 등등...

let decl: DeclSyntax = """
    extension MyState: SomeProtocol {
        // ...
    }
"""
```

#### `\(type.trimmed)`

타입 이름을 보간합니다.

```swift
// type: "MyState"
// type.trimmed: 앞뒤 공백 제거

extension \(type.trimmed): ObservableStateProtocol {
// → extension MyState: ObservableStateProtocol {
```

**trimmed란?**

Syntax 노드의 앞뒤 Trivia(공백, 주석 등)를 제거합니다:

```swift
// Trivia 포함
let typeWithTrivia = "  MyState  "

// Trivia 제거
let type = typeWithTrivia.trimmed  // "MyState"
```

#### `\(raw: keyPathsArray)`

raw 보간을 사용하여 문자열을 그대로 삽입합니다.

```swift
let keyPathsArray = #"\Self.count, \Self.isLoading"#

// 일반 보간 (이스케이프됨)
"\(keyPathsArray)"
// "\\Self.count, \\Self.isLoading" (백슬래시가 이중으로)

// raw 보간 (그대로 삽입)
"\(raw: keyPathsArray)"
// "\Self.count, \Self.isLoading" (원본 그대로)
```

### 10. ExtensionDeclSyntax로 캐스팅

```swift
guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
    throw MacroError.invalidExtension
}

return [ext]
```

생성한 DeclSyntax를 ExtensionDeclSyntax로 캐스팅하여 반환합니다.

## 에러 타입

```swift
enum MacroError: Error, CustomStringConvertible {
    case notAStruct
    case noStoredProperties
    case invalidExtension

    var description: String {
        switch self {
        case .notAStruct:
            return "@ObservableState can only be applied to structs"
        case .noStoredProperties:
            return "@ObservableState requires at least one stored property"
        case .invalidExtension:
            return "Failed to generate extension code"
        }
    }
}
```

### `CustomStringConvertible`

에러 메시지를 커스터마이즈할 수 있게 합니다.

```swift
// CustomStringConvertible 없이
print(MacroError.notAStruct)
// "notAStruct" (enum case 이름)

// CustomStringConvertible 구현 후
print(MacroError.notAStruct)
// "@ObservableState can only be applied to structs" (설명 메시지)
```

## 전체 동작 흐름

```
┌─────────────────────────────────────────────────────────────┐
│ 1. 소스 코드                                                 │
│    @ObservableState                                          │
│    struct MyState {                                          │
│        var count: Int = 0                                    │
│        var isLoading: Bool = false                           │
│    }                                                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. SwiftSyntax 파싱                                          │
│    StructDeclSyntax(                                         │
│        name: "MyState",                                      │
│        members: [                                            │
│            VariableDeclSyntax(pattern: "count", ...),       │
│            VariableDeclSyntax(pattern: "isLoading", ...)    │
│        ]                                                     │
│    )                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. 매크로 expansion 호출                                     │
│    ObservableStateMacro.expansion(                           │
│        declaration: StructDeclSyntax,                        │
│        type: "MyState",                                      │
│        ...                                                   │
│    )                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. 저장 프로퍼티 추출                                         │
│    properties = [                                            │
│        VariableDeclSyntax(pattern: "count"),                │
│        VariableDeclSyntax(pattern: "isLoading")             │
│    ]                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. KeyPath 배열 생성                                         │
│    keyPathsArray = "\Self.count, \Self.isLoading"          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. switch cases 생성                                         │
│    switchCases = """                                         │
│        case \Self.count:                                     │
│            return oldValue.count != newValue.count           │
│        case \Self.isLoading:                                 │
│            return oldValue.isLoading != newValue.isLoading   │
│    """                                                       │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Extension 코드 생성                                        │
│    extension MyState: ObservableStateProtocol {              │
│        public static var _$observableKeyPaths: ... {         │
│            [\Self.count, \Self.isLoading]                   │
│        }                                                     │
│        public static func hasChanged(...) -> Bool {          │
│            switch keyPath {                                  │
│            case \Self.count:                                 │
│                return oldValue.count != newValue.count       │
│            case \Self.isLoading:                             │
│                return old...isLoading != new...isLoading     │
│            default:                                          │
│                return false                                  │
│            }                                                 │
│        }                                                     │
│    }                                                         │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│ 8. 컴파일러에 반환                                            │
│    return [ExtensionDeclSyntax]                              │
└─────────────────────────────────────────────────────────────┘
```

## 핵심 개념 정리

### 1. SwiftSyntax
Swift 코드를 구조화된 트리로 표현하고 조작하는 라이브러리

### 2. Syntax Tree
코드를 트리 구조로 표현 (struct → members → properties)

### 3. compactMap
map + nil 제거를 한 번에 수행

### 4. raw 문자열 보간
\(raw: value)로 이스케이프 없이 문자열 삽입

### 5. 멀티라인 문자열
"""로 여러 줄 문자열을 쉽게 작성

## 다음 단계

이제 ReducerKit의 모든 핵심 컴포넌트를 이해했습니다!

- [01_Core_Reducer.md](./01_Core_Reducer.md) - 처음부터 다시 복습
- [Examples/Counter](../Examples/Counter) - 실제 동작하는 예제 코드
