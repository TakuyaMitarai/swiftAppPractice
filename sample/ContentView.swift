//
//  ContentView.swift
//  sample
//
//  Created by Takuya M on 2025/06/03.
//

import SwiftUI


import SwiftUI


struct ContentView: View {
    @State private var names: [String] = ["Elisha", "Andre", "Jasmine", "Po-Chun"]
    @State private var nameToAdd = ""
    @State private var pickedName = ""
    @State private var shouldRemovePickedName = false
    
    var body: some View {
        VStack {
            Text(pickedName.isEmpty ? "" : pickedName)
            List {
                ForEach(names, id: \.description) { name in
                    Text(name)
                }
            }
            Text(nameToAdd)
            TextField("Add Name", text: $nameToAdd)
                .onSubmit {
                    if !nameToAdd.isEmpty{
                        names.append(nameToAdd)
                        nameToAdd = ""
                    }
                }
            
            Toggle("Remove when picked", isOn: $shouldRemovePickedName)
            
            Button {
                if let randomName = names.randomElement() {
                    pickedName = randomName
                    
                    if shouldRemovePickedName {
                        names.removeAll { name in
                            return (name == randomName)
                        }
                    }
                } else {
                    pickedName = ""
                }
            } label: {
                Text("Pick Random Name")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.borderedProminent)
            .font(.title2)
        }
        .padding()
    }
}


#Preview {
    ContentView()
}
