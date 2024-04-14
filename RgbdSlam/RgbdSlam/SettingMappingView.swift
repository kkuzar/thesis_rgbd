//
//  SettingMappingView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 14.4.2024.
//

import SwiftUI

struct SettingMappingView: View {
    var body: some View {
        
        NavigationView {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .animation(Animation.easeIn(duration: 0.4))
        .navigationTitle("Mapping Settings")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: ToolbarItemPlacement.navigationBarLeading) {
                NavigationLink(destination: SettingsView() ) {
                    Text(Image(systemName: "chevron.backward")) + Text(" Settings")
                }
            }
        }
    }
}

#Preview {
    SettingMappingView()
}
