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
    
    var body: some View {
        
        NavigationView {
            List {

                Section("Cloud status") {
                    if firebaseManager.isConnected {
                        Text("Connected to Firebase ✅")
                            .foregroundColor(.green)
                    } else {
                        Text("Checking connection to Firebase...❌")
                            .foregroundColor(.red)
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
}


#Preview {
    SettingsView()
}
