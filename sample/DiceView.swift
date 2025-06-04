//
//  DiceView.swift
//  sample
//
//  Created by Takuya M on 2025/06/03.
//

import SwiftUI


struct DiceView: View {
    @State private var numberOfPips: Int = 1
    
    var body: some View {
        VStack {
            //　ダイスが1なら.accent それ以外なら黒
            if numberOfPips == 1 {
                Image(systemName: "die.face.\(numberOfPips).fill")
                    .resizable()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .aspectRatio(1, contentMode: .fit)
                    .foregroundStyle(.accent, .white)
            } else {
                Image(systemName: "die.face.\(numberOfPips).fill")
                    .resizable()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .aspectRatio(1, contentMode: .fit)
                    .foregroundStyle(.black, .white)
            }
            
            Button("Roll") {
                withAnimation {
                    numberOfPips = Int.random(in: 1...6)
                }
            }
            .buttonStyle(.bordered)
        }
    }
}


#Preview {
    DiceView()
}
