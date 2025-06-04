//
//  ContentView.swift
//  sample
//
//  Created by Takuya M on 2025/06/03.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showImageEditor = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 50) {
                Text("画像編集アプリ")
                    .font(.largeTitle)
                    .bold()
                
                Button(action: {
                    showImageEditor = true
                }) {
                    VStack(spacing: 15) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 60))
                        Text("画像編集を開始")
                            .font(.headline)
                    }
                    .padding(30)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ホーム")
            .fullScreenCover(isPresented: $showImageEditor) {
                ImageSelectionView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: EditedImageModel.self, inMemory: true)
}


