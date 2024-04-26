//
//  ContentView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 12.4.2024.
//

import SwiftUI
import SwiftData
import FirebaseAuth
import FirebaseStorage


struct ContentView: View {
    
    
    @StateObject var model = ScanFilesModel()
    @StateObject var authUser = AuthUser()
    
//    @State private var uploadProgress: Float = 0.0
//    @State private var isUploading = false
    
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
//                            .onTapGesture(count: 2) {
//                                print("double tap")
//                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    model.remove(fileURL: model.scanFiles[index].scanPath)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
//                            .swipeActions(edge: .leading) {
//                                Button {
//                                    model.upload()
//                                } label: {
//                                    Label("Upload", systemImage: "square.and.arrow.up.circle.fill")
//                                }
//                                .tint(.blue)
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
    
//    func uploadFile(fileURL: URL) {
//            guard let user = Auth.auth().currentUser else {
//                print("User not authenticated")
//                return
//            }
//            
//            // Simulated file data and path
//            let data = Data("File content".utf8)
//            let path = "uploads/\(user.uid)/file.txt"
//            
//            let storageRef = Storage.storage().reference(withPath: path)
//            let uploadTask = storageRef.putData(data, metadata: nil) { metadata, error in
//                self.isUploading = false
//                if let error = error {
//                    print("Error uploading file: \(error.localizedDescription)")
//                    return
//                }
//                print("Upload complete: \(metadata?.path ?? "Unknown path")")
//            }
//            
//            // Handle upload progress
//            uploadTask.observe(.progress) { snapshot in
//                guard let progress = snapshot.progress else { return }
//                self.uploadProgress = Float(progress.fractionCompleted)
//                self.isUploading = true
//            }
//        }
    
}
