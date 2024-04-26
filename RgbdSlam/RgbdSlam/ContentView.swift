//
//  ContentView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 12.4.2024.
//

import SwiftUI
import SwiftData
import FirebaseAuth



struct ContentView: View {
    
    
    @StateObject var model = ScanFilesModel()
    @StateObject var authUser = AuthUser()
    @State private var showAlert = false
    
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
                    .padding()
                Spacer()
                if let user = authUser.user {
                    Text("Hello, \(user.email ?? "User")")
                        .foregroundStyle(.green)
                        .padding()
                        .font(.system(size: 12))
                } else {
                    Text("User not signed into Cloud yet")
                        .foregroundColor(.gray)
                        .padding()
                        .font(.system(size: 12))
                }
                
                Spacer()
                
                if model.scanFiles.size() != 0 {
                    List {
                        ForEach(model.scanFiles.indices, id:\.self) { index in
                            let item = model.scanFiles[index]
                            HStack {
                                
                                VStack(alignment: .leading) {
                                    Text(item.scanName)
                                        .font(.headline)
                                        .font(.system(size: 20))
                                    Text("Size: \(item.scanSizeString)\nCreated: " +
                                         (try! item.scanDate?.getFormattedDate(format: "dd-MM-yyyy HH:mm:ss") ?? "Date not available"))
                                    .font(.system(size: 12))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                }
                            }
                            .onTapGesture(count: 2) {
                                print("double tap")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    model.remove()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    model.rename()
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.gray)
                                
                                Button {
                                    model.upload()
                                } label: {
                                    Label("Upload", systemImage: "square.and.arrow.up.circle.fill")
                                }
                                .tint(.blue)
                            }
                            .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 10, pressing: { isPressing in
                                if isPressing {
                                   //
                                } else {
                                   
                                }
                            }) {
                                print("Long press detected")
                                showAlert = true
                                
                            }
                            .sheet(isPresented: $showAlert) {
                                // Assuming you have an image named 'photo' in your assets
                                ThumbnailAlertView(isPresented: $showAlert, image: item.scanThumbnail ?? UIImage(systemName: "photo")!)
                            }
                            
                        }
                    }
                } else {
                    Text("No Scans in Library yet.")
                        .foregroundColor(.gray)
                        .padding()
                        .font(.system(size: 30))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing){
                    NavigationLink{
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
        .animation(Animation.easeIn(duration: 0.1))
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
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
