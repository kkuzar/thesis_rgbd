//
//  ContentView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 12.4.2024.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    // private var rtabmap: RTABMap?
    
    var body: some View {
        NavigationSplitView {
            
            VStack{
                Spacer()
                NavigationLink (destination: RgbdCaptureView()) {
                    Text(Image(systemName: "plus.circle.fill")) + Text("Start new scan")
                }.padding()
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(10)
                Spacer()
                List {
                    Section {
                        if items.isEmpty {
                            Text("There is no preview scan files")
                        }
                        ForEach(items) { item in
                            NavigationLink {
                                Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                            } label: {
                                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                            }
                        }
                        .onDelete(perform: deleteItems)
                    } header: {
                        Text("Scan Library")
                    }
                }.padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing){
                    NavigationLink{
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .animation(Animation.easeIn(duration: 0.1))
        .navigationBarBackButtonHidden(true)
    }
    
    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
