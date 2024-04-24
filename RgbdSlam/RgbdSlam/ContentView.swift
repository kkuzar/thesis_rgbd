//
//  ContentView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 12.4.2024.
//

import SwiftUI
import SwiftData

class ScanModel: ObservableObject {
    @Published var dbFiles: [URL] = []
    
    func fetchDatabaseFiles() {
        let fileManager = FileManager.default
        do {
            // Get the URL for the Documents Directory
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            
            // Get the contents of the Documents Directory
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            // Filter files to find those ending with '.db'
            dbFiles = files.filter { $0.pathExtension == "db" }
            
        } catch {
            print("Error while fetching files: \(error)")
        }
    }
}



struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // private var rtabmap: RTABMap?
    
    @ObservedObject var viewModel = ScanModel()
   
    
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
//                        if items.isEmpty {
//                            Text("There is no preview scan files")
//                        }
                        //                        ForEach(items) { item in
                        //                            NavigationLink {
                        //                                Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                        //                            } label: {
                        //                                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                        //                            }
                        //                        }
                        //                        .onDelete(perform: deleteItems)
                        List(fetchDatabaseFiles(), id: \.self) { file in
                            Text(file)
                        }
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
//                ToolbarItem {
//                    Button(action: addItem) {
//                        Label("Add Item", systemImage: "plus")
//                    }
//                }
            }
        } detail: {
            Text("Select an item")
        }
        .animation(Animation.easeIn(duration: 0.1))
        .navigationBarBackButtonHidden(true)
    }
    
    func fetchDatabaseFiles() -> [String] {
        let fileManager = FileManager.default
        do {
            // Get the URL for the documents directory
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            
            // List all files in the directory
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            
            // Filter files to include only *.db files
            let dbFiles = files.filter { $0.pathExtension == "db" }.map { $0.lastPathComponent }
            
            return dbFiles
        } catch {
            print("Error fetching database files: \(error)")
            return []
        }
    }
    
//    private func addItem() {
//        withAnimation {
//            let newItem = Item(timestamp: Date())
//            modelContext.insert(newItem)
//        }
//    }
//    
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
}

#Preview {
    ContentView()
        // .modelContainer(for: Item.self, inMemory: true)
}
