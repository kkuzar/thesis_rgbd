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
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/).navigationTitle("Settings")
    
        VStack(alignment: .center) {
            Toggle(isOn: self.$settingForm.Blending) {
                Text("Bleeding")
            }
        }
    }
}

#Preview {
    SettingsView()
}
