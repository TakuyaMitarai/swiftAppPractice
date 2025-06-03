//
//  ContentView.swift
//  sample
//
//  Created by Takuya M on 2025/06/03.
//

import SwiftUI

let gradientColors: [Color] = [
    .gradientTop,
    .gradientBottom
]

//struct ContentView: View {
//    var body: some View {
//        TabView {
//            WelcomePage()
//            FeaturesPage()
//        }
//        .background(Gradient(colors: gradientColors))
//        .tabViewStyle(.page)
//        .foregroundStyle(.white)
//    }
//}

struct ContentView: View {
    @State private var numberOfDice: Int = 1
    var body: some View {
        VStack {
            Text("Dice Roller")
                .font(.largeTitle.lowercaseSmallCaps())
            
            HStack {
                ForEach(1...numberOfDice, id: \.description) { _ in
                    DiceView()
                }
            }
            HStack {
                Button("Remove Dice") {
                    numberOfDice -= 1
                }
                .disabled(numberOfDice == 1)
                
                Button("Add Dice") {
                    numberOfDice += 1
                }
                .disabled(numberOfDice == 5)
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

