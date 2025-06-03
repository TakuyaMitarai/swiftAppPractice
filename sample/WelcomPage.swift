//
//  WelcomPage.swift
//  sample
//
//  Created by Takuya M on 2025/06/03.
//

import SwiftUI

struct WelcomePage: View {
    var body: some View {
        VStack {
            ZStack{
                RoundedRectangle(cornerRadius: 90)
                    .frame(width: 200, height: 200)
                    .padding(50)
                    .foregroundStyle(.tint)
                
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 100))
                    .foregroundStyle(.white)
            }
            
            Text("Welcome to My App")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Description text")
                .font(.title2)
                .padding()
        }
        .padding()
    }
}

#Preview {
    WelcomePage()
}
