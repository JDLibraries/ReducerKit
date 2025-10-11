# ReducerKit 문서

ReducerKit의 ObservableState 매크로와 Store 구현에 대한 상세한 설명입니다.

## 읽는 순서

이 문서들은 구현 순서대로 작성되었습니다. 처음부터 순서대로 읽는 것을 권장합니다.

### 1. Core 컴포넌트

ReducerKit의 기본 구성 요소들입니다.

1. **[Reducer 프로토콜](./01_Core_Reducer.md)** ⭐ 시작하기
   - Reducer의 역할과 순수 함수 개념
   - Associated Type (State, Action)
   - inout 파라미터의 의미
   - 실제 구현 예시

2. **[Effect 타입](./02_Core_Effect.md)**
   - 부수 효과(Side Effect)란?
   - .none과 .run case
   - 제네릭과 연관값(Associated Value)
   - 비동기 작업 처리

3. **[Send 타입](./03_Core_Send.md)**
   - Effect 내부에서 액션 전송
   - @escaping 클로저와 캡처 리스트
   - callAsFunction의 활용
   - 전체 데이터 흐름

### 2. Observable 시스템

KeyPath 기반 세밀한 관찰을 위한 컴포넌트들입니다.

4. **[ObservableStateProtocol](./04_ObservableStateProtocol.md)**
   - 세밀한 관찰이 필요한 이유
   - KeyPath와 PartialKeyPath
   - _$observableKeyPaths와 hasChanged 메서드
   - Store에서의 활용

5. **[Store 타입](./05_Store.md)** ⭐ 핵심
   - @MainActor, @Observable, @dynamicMemberLookup
   - ObservableVersion 패턴
   - KeyPath별 버전 관리
   - send → updateVersions → View 업데이트 흐름
   - 전체 동작 다이어그램

### 3. 매크로 시스템

코드 자동 생성을 위한 매크로입니다.

6. **[ObservableState 매크로](./06_ObservableState_Macro.md)**
   - 매크로란 무엇인가?
   - @attached(extension) 어트리뷰트
   - #externalMacro와 컴파일러 플러그인
   - 사용법과 제약사항

7. **[매크로 구현](./07_ObservableStateMacro_Implementation.md)** ⭐ 심화
   - SwiftSyntax와 Syntax Tree
   - 코드 파싱과 분석
   - Extension 코드 생성
   - 전체 동작 흐름

## 주요 개념

### Swift 문법

이 문서에서 자세히 설명하는 Swift 개념들:

- **Associated Type**: 프로토콜의 타입 플레이스홀더
- **inout 파라미터**: 참조로 전달하여 직접 수정
- **제네릭(Generic)**: 구체적인 타입을 나중에 결정
- **클로저(Closure)**: 이름 없는 함수를 값처럼 다루기
- **KeyPath**: 프로퍼티의 경로를 타입 안전하게 표현
- **@escaping**: 함수 실행 후에도 살아남는 클로저
- **callAsFunction**: 객체를 함수처럼 호출
- **@MainActor**: 메인 스레드 실행 보장
- **@Observable**: Swift 5.9의 새로운 관찰 시스템
- **@dynamicMemberLookup**: 존재하지 않는 프로퍼티 접근 가로채기
- **매크로(Macro)**: 컴파일 시점 코드 생성

### 디자인 패턴

- **순수 함수(Pure Function)**: Reducer의 핵심
- **단방향 데이터 흐름**: View → Action → Reducer → State → View
- **부수 효과 분리**: 상태 변경과 비동기 작업의 분리
- **KeyPath 기반 관찰**: 변경된 프로퍼티만 View 업데이트

## 다이어그램 모음

### 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│ View                                                         │
│   - store.count 읽기 (dynamicMemberLookup)                  │
│   - store.send(.action) 호출                                │
└─────────────────┬──────────────────────┬────────────────────┘
                  │                      │
                  │ 읽기                 │ 액션 전송
                  ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Store (@MainActor @Observable)                               │
│   - subscript(dynamicMember:) → ObservableVersion 관찰 등록  │
│   - send(_:) → Reducer 호출 → updateVersions                │
└─────────────────┬──────────────────────┬────────────────────┘
                  │                      │
                  │ reduce 호출          │ Effect 실행
                  ▼                      ▼
┌──────────────────────────┐  ┌──────────────────────────────┐
│ Reducer                  │  │ Effect                       │
│   - reduce(state, action)│  │   - .none or .run { send }   │
│   - return Effect        │  │   - 비동기 작업 실행          │
└──────────────────────────┘  └──────────────┬───────────────┘
                                              │
                                              │ send(.newAction)
                                              ▼
                                    ┌──────────────────────┐
                                    │ Send                 │
                                    │   - Store.send 호출  │
                                    └──────────────────────┘
```

### KeyPath 기반 관찰

```
State { count, isLoading, text }
   │
   ├─ \State.count ──────┐
   ├─ \State.isLoading ──┼─ Store._$observableKeyPaths
   └─ \State.text ───────┘
                          │
                          ▼
              ┌─────────────────────────────────┐
              │ observableVersions Dictionary   │
              │                                 │
              │  \.count     → ObservableVersion│
              │  \.isLoading → ObservableVersion│
              │  \.text      → ObservableVersion│
              └─────────────┬───────────────────┘
                            │
                            │ View가 store.count 읽을 때
                            ▼
                  ObservableVersion.value 읽기
                  → @Observable이 View 등록
                            │
                            │ count 변경 시
                            ▼
                  ObservableVersion.value += 1
                  → 등록된 View에 알림
```

## 실전 팁

### 최적화된 View 작성

```swift
// ❌ 비효율적 - state 전체를 관찰 (모든 프로퍼티 변경 시 업데이트)
Text("\(store.state.count)")

// ✅ 효율적 - count만 관찰 (count 변경 시에만 업데이트)
Text("\(store.count)")
```

**state 프로퍼티 사용이 적절한 경우:**
- 전체 State를 함수에 전달: `processState(store.state)`
- 디버깅: `print("State:", store.state)`
- 스냅샷 저장: `let snapshot = store.state`

### 디버깅

```swift
// 매크로가 생성한 코드 확인
// Xcode에서 @ObservableState 우클릭 → Expand Macro

// Store의 버전 변경 확인
print(store._keyPathVersions)  // [\.count: 5, \.isLoading: 2]
```

### 테스트

```swift
// Store는 테스트하기 쉬움
let store = Store(
    initialState: State(count: 0),
    reducer: TestReducer()
)

store.send(.increment)
XCTAssertEqual(store.state.count, 1)
```

## 참고 자료

### 공식 문서
- [Swift Macros](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)
- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [SwiftSyntax](https://github.com/apple/swift-syntax)

### 유사 라이브러리
- [TCA (The Composable Architecture)](https://github.com/pointfreeco/swift-composable-architecture)
- [Redux](https://redux.js.org/) (JavaScript)

## 질문과 답변

### Q: @ObservableState 없이 사용할 수 있나요?
A: 아니요. Store는 `R.State: ObservableStateProtocol` 제약이 있어서 반드시 @ObservableState가 필요합니다.

### Q: class State는 지원하나요?
A: 아니요. State는 값 타입(struct)이어야 합니다. 불변성과 Equatable 구현을 위해서입니다.

### Q: nested State에서도 세밀한 관찰이 되나요?
A: 최상위 State의 프로퍼티 레벨까지만 세밀하게 관찰됩니다. 예를 들어 `store.user.name`에서 `user`가 변경되면 업데이트되지만, `name`만 변경되는 것은 감지하지 못합니다.

### Q: 매크로 없이 수동으로 구현할 수 있나요?
A: 네, ObservableStateProtocol을 직접 구현하면 됩니다. 하지만 프로퍼티 추가/제거 시 extension도 수동으로 업데이트해야 합니다.

## 기여하기

버그를 발견하거나 개선 제안이 있다면 이슈를 등록해주세요.

---

문서 작성일: 2025-10-11
ReducerKit 버전: 최신 커밋 기준
