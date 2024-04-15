//
//  CaptureView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import SwiftUI

struct RgbdCaptureView: View {
    
    // MARK: View body
    var body: some View {
        VStack {
            RGBDCaptureViewControllerWrapper()
            Button(action: testAction) {
                Label("Add Item", systemImage: "plus")
            }
        }.navigationBarBackButtonHidden(true)
    }
  
    // MARK: Functions
    
    private func testAction() {
        NSLog("Swift UI action btn")
    }

}


#Preview {
    RgbdCaptureView()
}
