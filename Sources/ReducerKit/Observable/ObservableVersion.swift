//
//  ObservableVersion.swift
//  ReducerKit
//
//  Created by ReducerKit on 11/01/25.
//

import Foundation

/// KeyPath별 버전을 개별적으로 관찰 가능하게 만드는 래퍼
///
/// Store에서 프로퍼티별 세밀한 관찰을 구현하기 위해,
/// 각 KeyPath의 변경을 독립적으로 추적하는 Observable 래퍼입니다.
///
/// ## 동작 원리
///
/// - View가 `store.count`에 접근하면, 내부적으로 이 ObservableVersion의 `value`를 읽습니다.
/// - @Observable 시스템이 이 읽기 접근을 감지하여 View를 관찰자로 등록합니다.
/// - `value`가 증가하면 관찰자(View)에게 변경 알림이 전송됩니다.
///
/// ## 구현 상세
///
/// Store에서 프로퍼티가 변경되면:
/// 1. updateVersions 메서드에서 변경된 KeyPath를 감지합니다.
/// 2. 해당 ObservableVersion의 value를 증가시킵니다.
/// 3. @Observable이 이를 감지하여 관찰자에게 알립니다.
///
/// 예시:
/// ```swift
/// // value 값 자체는 의미가 없고,
/// // 변경 횟수만 중요합니다.
/// observableVersions[\.count].value = 0
/// observableVersions[\.count].value = 1  // 변경 감지
/// observableVersions[\.count].value = 2  // 다시 변경 감지
/// ```
///
/// - SeeAlso: ``Store``, ``ObservableStateProtocol``
@Observable
internal final class ObservableVersion {
    var value: Int = 0
}
