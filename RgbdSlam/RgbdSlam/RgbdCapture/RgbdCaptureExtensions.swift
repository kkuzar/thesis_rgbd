//
//  RgbdCaptureExtensions.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 14.4.2024.
//

import Foundation
import StoreKit

//enum State {
//    case STATE_WELCOME,    // Camera/Motion off - showing only buttons open and start new scan
//         STATE_CAMERA,          // Camera/Motion on - not mapping
//         STATE_MAPPING,         // Camera/Motion on - mapping
//         STATE_IDLE,            // Camera/Motion off
//         STATE_PROCESSING,      // Camera/Motion off - post processing
//         STATE_VISUALIZING,     // Camera/Motion off - Showing optimized mesh
//         STATE_VISUALIZING_CAMERA,     // Camera/Motion on  - Showing optimized mesh
//         STATE_VISUALIZING_WHILE_LOADING // Camera/Motion off - Loading data while showing optimized mesh
//}

extension SKStoreReviewController {
    public static func requestReviewInCurrentScene() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            requestReview(in: scene)
        }
    }
}

extension DispatchQueue {

    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            background?()
            if let completion = completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: {
                    completion()
                })
            }
        }
    }
}

