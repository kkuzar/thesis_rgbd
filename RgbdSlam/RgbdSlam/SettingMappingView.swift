//
//  SettingMappingView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 14.4.2024.
//

import SwiftUI

struct SettingMappingView: View {
    var body: some View {
        
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.red)
                .frame(width: 100, height: 50)
            Rectangle()
                .fill(Color.blue)
                .frame(width:50, height: 100)
        }
        .border(Color.green, width: 1)
        
//        NavigationView {
//            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
//        }
//        .animation(Animation.easeIn(duration: 0.4))
//        .navigationTitle("Mapping Settings")
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: ToolbarItemPlacement.navigationBarLeading) {
//                NavigationLink(destination: SettingsView() ) {
//                    Text(Image(systemName: "chevron.backward")) + Text(" Settings")
//                }
//            }
//        }
    }
}

#Preview {
    SettingMappingView()
}
