//
//  UserSettings.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import Foundation

class UserSettingsModel: ObservableObject{
    static let shared = UserSettingsModel()
    
    // Update Preferences
    @Published var Blending:Bool {
        didSet {
            UserDefaults.standard.set(self.Blending, forKey: "Blending")
        }
    }
    
//    @Published var NodesFiltering = UserDefaults.standard.bool(forKey: "NodesFiltering") {
//        didSet {
//            UserDefaults.standard.set(self.NodesFiltering, forKey: "NodesFiltering")
//        }
//    }
//    
//    @Published var HDMode = UserDefaults.standard.bool(forKey: "HDMode") {
//        didSet {
//            UserDefaults.standard.set(self.HDMode, forKey: "HDMode")
//        }
//    }
//    
//    @Published var Smoothing = UserDefaults.standard.bool(forKey: "Smoothing") {
//        didSet {
//            UserDefaults.standard.set(self.Smoothing, forKey: "Smoothing")
//        }
//    }
//    
//    @Published var AppendMode = UserDefaults.standard.bool(forKey: "AppendMode") {
//        didSet {
//            UserDefaults.standard.set(self.AppendMode, forKey: "AppendMode")
//        }
//    }
//    
//    @Published var TimeLimit = UserDefaults.standard.string(forKey: "TimeLimit") {
//        didSet {
//            UserDefaults.standard.set(self.TimeLimit, forKey: "TimeLimit")
//        }
//    }
//    @Published var mTimeThr = (UserDefaults.standard.string(forKey: "TimeLimit")! as NSString).integerValue
//    
//    @Published var MaxFeaturesExtractedLoopClosure = UserDefaults.standard.string(forKey: "MaxFeaturesExtractedLoopClosure") {
//        didSet {
//            UserDefaults.standard.set(self.MaxFeaturesExtractedLoopClosure, forKey: "MaxFeaturesExtractedLoopClosure")
//        }
//    }
//    @Published var mMaxFeatures = (UserDefaults.standard.string(forKey: "MaxFeaturesExtractedLoopClosure")! as NSString).integerValue
//    
//    
//    // Mapping Params
//    @Published var UpdateRate = UserDefaults.standard.string(forKey: "UpdateRate") {
//        didSet {
//            UserDefaults.standard.set(self.UpdateRate, forKey: "UpdateRate")
//        }
//    }
//    @Published var MemoryLimit = UserDefaults.standard.string(forKey: "MemoryLimit") {
//        didSet {
//            UserDefaults.standard.set(self.MemoryLimit, forKey: "MemoryLimit")
//        }
//    }
//    @Published var MaximumMotionSpeed = UserDefaults.standard.string(forKey: "MaximumMotionSpeed") {
//        didSet {
//            UserDefaults.standard.set(self.MaximumMotionSpeed, forKey: "MaximumMotionSpeed")
//        }
//    }
//    @Published var motionSpeed = (UserDefaults.standard.string(forKey: "MaximumMotionSpeed")! as NSString).floatValue / 2.0

    @Published var LoopClosureThreshold: String {
        didSet {
            UserDefaults.standard.set(self.LoopClosureThreshold, forKey: "LoopClosureThreshold")
        }
    }
    
    private init() {
        self.Blending = UserDefaults.standard.bool(forKey: "Bleeding")
        self.LoopClosureThreshold = UserDefaults.standard.string(forKey: "LoopClosureThreshold") ?? ""
    }
}
