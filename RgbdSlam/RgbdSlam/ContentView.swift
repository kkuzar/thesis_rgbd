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
    
    //    @State private var showThumbnail = false
    //    @State private var showAlertDelete = false
    
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
                                NavigationLink (destination: RGBDCaptureViewControllerWrapper(loadFileURL: item.scanPath, isLoadFile: true)
                                    .edgesIgnoringSafeArea(.all)) {
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
                
                            }
                            .onTapGesture(count: 2) {
                                print("double tap")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    model.remove(fileURL: model.scanFiles[index].scanPath)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                //                                Button {
                                //                                    showRename = true
                                //                                } label: {
                                //                                    Label("Rename", systemImage: "pencil")
                                //                                }
                                //                                .tint(.gray)
                                
                                Button {
                                    model.upload()
                                } label: {
                                    Label("Upload", systemImage: "square.and.arrow.up.circle.fill")
                                }
                                .tint(.blue)
                            }
                            //                            .onLongPressGesture(minimumDuration: 0.2, maximumDistance: 10, pressing: { isPressing in
                            //                                if isPressing {
                            //                                    //
                            //                                } else {
                            //
                            //                                }
                            //                            }) {
                            //                                print("Long press detected")
                            //                                showThumbnail = true
                            //
                            //                            }
                            //                            .sheet(isPresented: $showThumbnail) {
                            //                                // Assuming you have an image named 'photo' in your assets
                            //                                ThumbnailAlertView(isPresented: $showThumbnail, image: model.scanFiles[index].scanThumbnail ?? UIImage(systemName: "photo")!)
                            //                            }
                            //                            .alert("Delete Scan?", isPresented: $showAlertDelete) {
                            //                                Button("Cancel", role: .cancel) {
                            //                                    showAlertDelete = false
                            //                                }
                            //                                Button("Delete", role: .destructive) {
                            //                                    model.remove(fileURL: item.scanPath)
                            //                                    showAlertDelete = false
                            //                                }
                            //                            } message: {
                            //                                Text("Are you sure delete this scan file?")
                            //                            }
                            
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
    
    
    
    // View functions below
}
