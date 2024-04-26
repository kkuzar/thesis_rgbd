//
//  SettingsView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import SwiftUI
import Firebase


class FirebaseManager: ObservableObject {
    @Published var isConnected: Bool = false
    
    init() {
        // Check if Firebase is configured
        if FirebaseApp.app() != nil {
            self.isConnected = true
        } else {
            self.isConnected = false
        }
    }
}


struct SettingsView: View {
    @ObservedObject var settingForm = UserSettingsModel.shared
    @StateObject private var firebaseManager = FirebaseManager()
    @StateObject var authUser = AuthUser()
    
    @State private var isSignedOut = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        
        NavigationView {
            List {
                
                Section("Cloud status") {
                    if firebaseManager.isConnected {
                        Text("Connect to Cloud site success ✅")
                            .foregroundColor(.green)
                    } else {
                        Text("Checking connection to Cloud...❌")
                            .foregroundColor(.red)
                    }
                    
                    if let user = authUser.user {
                        Text("Hello, \(user.email ?? "User")")
                            .foregroundStyle(.green)
                        Button("Sign Out") {
                            signOut { success, message in
                                self.alertMessage = message
                                self.showingAlert = true
                                self.isSignedOut = success
                            }
                        }
                        .alert(isPresented: $showingAlert) {
                            Alert(title: Text("Sign Out"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                        }
                        .disabled(isSignedOut) // Disable button if signed out
                    } else {
                        Text("User not signed into cloud ⚠️")
                            .foregroundColor(.yellow)
                        
                        NavigationLink (destination: SettingFirebaseSignInView()) {
                            Text("Sign Into Cloud")
                        }
                    }
                }
                
                Section("Rendering") {
                    Picker("Point Cloud Density",
                           selection: $settingForm.PointCloudDensity){
                        ForEach(PCDenOption){ PCDenOption in
                            Text(PCDenOption.label)
                                .tag(PCDenOption.value)
                        }
                    }
                    Picker("Max Depth",
                           selection: $settingForm.MaxDepth){
                        ForEach(MaxDepOptions){ MaxDepOptions in
                            Text(MaxDepOptions.label)
                                .tag(MaxDepOptions.value)
                        }
                    }
                    Picker("Min Depth",
                           selection: $settingForm.MinDepth){
                        ForEach(MinDepthOptions){ MinDepthOptions in
                            Text(MinDepthOptions.label)
                                .tag(MinDepthOptions.value)
                        }
                    }
                    Picker("Depth Confidence",
                           selection: $settingForm.DepthConfidence){
                        ForEach(DepthConOption){ DepthConOption in
                            Text(DepthConOption.label)
                                .tag(DepthConOption.value)
                        }
                    }
                    Picker("Mesh Angle Tolerance (deg)",
                           selection: $settingForm.MeshAngleTolerance){
                        ForEach(MeshAngTolOption){ MeshAngTolOption in
                            Text(MeshAngTolOption.label)
                                .tag(MeshAngTolOption.value)
                        }
                    }
                    Picker("Mesh Triangle Size",
                           selection: $settingForm.MeshTriangleSize){
                        ForEach(MeshTriOptions){ MeshTriOptions in
                            Text(MeshTriOptions.label)
                                .tag(MeshTriOptions.value)
                        }
                    }
                    Picker("Mesh Decimation Factor",
                           selection: $settingForm.MeshDecimationFactor){
                        ForEach(MeshDeciOption){ MeshDeciOption in
                            Text(MeshDeciOption.label)
                                .tag(MeshDeciOption.value)
                        }
                    }
                    Picker("Texture Resolution",
                           selection: $settingForm.TextureResolution){
                        ForEach(TextureOptions){ TextureOptions in
                            Text(TextureOptions.label)
                                .tag(TextureOptions.value)
                        }
                    }
                    Picker("Background Color",
                           selection: $settingForm.BackgroundColor){
                        ForEach(BgColorOption){ BgColorOption in
                            Text(BgColorOption.label)
                                .tag(BgColorOption.value)
                        }
                    }
                    Picker("Point Size",
                           selection: $settingForm.PointSize){
                        ForEach(PointSizeOptions){ PointSizeOptions in
                            Text(PointSizeOptions.label)
                                .tag(PointSizeOptions.value)
                        }
                    }
                    Toggle(isOn: self.$settingForm.Blending) {
                        Text("Bleeding")
                    }
                    Toggle(isOn: self.$settingForm.NodesFiltering) {
                        Text("Nodes Filtering")
                    }
                }
                
                Section("General") {
                    NavigationLink (destination: SettingMappingView()) {
                        Text("Mapping Settings ...")
                    }
                    NavigationLink (destination: SettingAssembleView()) {
                        Text("Assemble Settings ...")
                    }
                }
                
                Section("Optimaize") {
                    Picker("Color Correction Radius",
                           selection: $settingForm.`ColorCorrectionRadius`){
                        ForEach(ColorRadiusOptions){ ColorRadiusOptions in
                            Text(ColorRadiusOptions.label)
                                .tag(ColorRadiusOptions.value)
                        }
                    }
                    Picker("Noise Filtering Ratio",
                           selection: $settingForm.NoiseFilteringRatio){
                        ForEach(NoiseRatioOptions){ NoiseRatioOptions in
                            Text(NoiseRatioOptions.label)
                                .tag(NoiseRatioOptions.value)
                        }
                    }
                }
                
                
            }
        }
        .navigationTitle("Settings")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: ToolbarItemPlacement.navigationBarLeading) {
                NavigationLink(destination: ContentView() ) {
                    Text(Image(systemName: "chevron.backward")) + Text(" Library")
                }
            }
        }
    }
    // function below
    func signOut(completion: @escaping (Bool, String) -> Void) {
        do {
            try Auth.auth().signOut()
            completion(true, "User signed out successfully.")
        } catch let signOutError as NSError {
            completion(false, "Error signing out: \(signOutError.localizedDescription)")
        }
    }
}


#Preview {
    SettingsView()
}
