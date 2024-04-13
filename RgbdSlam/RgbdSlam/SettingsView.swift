//
//  SettingsView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import SwiftUI

struct SettingsView: View {
    
    
    
    @ObservedObject var settingForm = UserSettingsModel.shared
    
    
    var body: some View {
        
        NavigationView {
            Form {
                LabeledContent("iOS Version", value: "2.2.1")
                
                Section("Rendering") {
                    Toggle(isOn: self.$settingForm.Blending) {
                        Text("Bleeding")
                    }
                }
                
                Section("General") {
                    Toggle(isOn: self.$settingForm.Blending) {
                        Text("Bleeding")
                    }
                    
                }
                
                Section("Optimaize") {
                    Toggle(isOn: self.$settingForm.Blending) {
                        Text("Bleeding")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
