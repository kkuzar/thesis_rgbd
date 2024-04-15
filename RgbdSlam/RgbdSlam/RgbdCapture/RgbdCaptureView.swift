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
        RGBDCaptureViewControllerWrapper()
            .edgesIgnoringSafeArea(.all)
            .highPriorityGesture(TapGesture().onEnded { _ in
                // This is just to show where you might configure SwiftUI to ignore gestures.
                // This might not be necessary if your UIKit handles gestures properly.
            })
    }
}


#Preview {
    RgbdCaptureView()
}
