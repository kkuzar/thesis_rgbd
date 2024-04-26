//
//  CaptureView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import SwiftUI

struct RgbdCaptureView: View {
    @StateObject var chosenScan = ChosenScan()
    // MARK: View body
    var body: some View {
        RGBDCaptureViewControllerWrapper()
            .environmentObject(chosenScan)
            .edgesIgnoringSafeArea(.all)
//            .highPriorityGesture(SimultaneousGesture.onChanged() { _ in
//                // This is just to show where you might configure SwiftUI to ignore gestures.
//                // This might not be necessary if your UIKit handles gestures properly.
//            })
    }
}


#Preview {
    RgbdCaptureView()
}
