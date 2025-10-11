//
//  ContentView.swift
//  Counter
//
//  Created by 이정동 on 10/3/25.
//

import SwiftUI

import ReducerKit

struct CounterView: View {

    @State private var store = Store(
        initialState: CounterReducer.State(),
        reducer: CounterReducer()
    )

    var body: some View {
        VStack(spacing: 40) {
            // 카운트 표시
            Text("\(store.count)")
                .font(.system(size: 80, weight: .bold))

            // 버튼들
            VStack(spacing: 16) {
                // 증가 버튼
                Button(action: {
                    store.send(.increment)
                }) {
                    Text("+")
                        .font(.title)
                        .frame(width: 200, height: 50)
                }
                .buttonStyle(.borderedProminent)

                // 감소 버튼
                Button(action: {
                    store.send(.decrement)
                }) {
                    Text("-")
                        .font(.title)
                        .frame(width: 200, height: 50)
                }
                .buttonStyle(.bordered)

                // 숫자 팩트 버튼
                Button(action: {
                    store.send(.numberFactButtonTapped)
                }) {
                    if store.isLoading {
                        ProgressView()
                            .frame(width: 200, height: 50)
                    } else {
                        Text("Get Number Fact")
                            .frame(width: 200, height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(store.isLoading)
            }

            // 숫자 팩트 표시
            NumberFactView(store: store)
        }
        .padding()
    }
}

private struct NumberFactView: View {
    
    let store: Store<CounterReducer>
    
    var body: some View {
        VStack {
            let _ = Self._printChanges()
            if let fact = store.numberFact {
                Text(fact)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(10)
            }
        }
    }
}

#Preview {
    CounterView()
}
