//
//  UserSettings.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import Foundation

public class UserSettingsModel: ObservableObject{
    static let shared = UserSettingsModel()
    
    // MARK: Update Preferences
    @Published var Blending:Bool {
        didSet {
            UserDefaults.standard.set(self.Blending, forKey: "Blending")
        }
    }
    
    @Published var NodesFiltering: Bool {
        didSet {
            UserDefaults.standard.set(self.NodesFiltering, forKey: "NodesFiltering")
        }
    }
    
    @Published var HDMode :Bool {
        didSet {
            UserDefaults.standard.set(self.HDMode, forKey: "HDMode")
        }
    }
    
    @Published var Smoothing: Bool{
        didSet {
            UserDefaults.standard.set(self.Smoothing, forKey: "Smoothing")
        }
    }
    
    @Published var AppendMode: Bool {
        didSet {
            UserDefaults.standard.set(self.AppendMode, forKey: "AppendMode")
        }
    }
    
    @Published var TimeLimit: String {
        didSet {
            UserDefaults.standard.set(self.TimeLimit, forKey: "TimeLimit")
        }
    }
    
    @Published var mTimeThr: Int
    
    @Published var MaxFeaturesExtractedLoopClosure : String {
        didSet {
            UserDefaults.standard.set(self.MaxFeaturesExtractedLoopClosure, forKey: "MaxFeaturesExtractedLoopClosure")
        }
    }
    @Published var mMaxFeatures : Int
    
    
    // MARK: Mapping Params
    @Published var UpdateRate : String {
        didSet {
            UserDefaults.standard.set(self.UpdateRate, forKey: "UpdateRate")
        }
    }
    
    @Published var MemoryLimit : String {
        didSet {
            UserDefaults.standard.set(self.MemoryLimit, forKey: "MemoryLimit")
        }
    }
    
    @Published var MaximumMotionSpeed : String {
        didSet {
            UserDefaults.standard.set(self.MaximumMotionSpeed, forKey: "MaximumMotionSpeed")
        }
    }
    
    @Published var motionSpeed : Float
    
    @Published var LoopClosureThreshold: String {
        didSet {
            UserDefaults.standard.set(self.LoopClosureThreshold, forKey: "LoopClosureThreshold")
        }
    }
    
    @Published var SimilarityThreshold: String {
        didSet {
            UserDefaults.standard.set(self.SimilarityThreshold, forKey: "SimilarityThreshold")
        }
    }
    
    @Published var MaxFeaturesExtractedVocabulary: String {
        didSet {
            UserDefaults.standard.set(self.MaxFeaturesExtractedVocabulary, forKey: "MaxFeaturesExtractedVocabulary")
        }
    }
    
    @Published var MinInliers: String {
        didSet {
            UserDefaults.standard.set(self.MinInliers, forKey: "MinInliers")
        }
    }
    
    @Published var FeatureType: String {
        didSet {
            UserDefaults.standard.set(self.FeatureType, forKey: "FeatureType")
        }
    }
    
    
    @Published var SaveAllFramesInDatabase: Bool {
        didSet {
            UserDefaults.standard.set(self.SaveAllFramesInDatabase, forKey: "SaveAllFramesInDatabase")
        }
    }
    
    
    @Published var OptimizationfromGraphEnd: Bool {
        didSet {
            UserDefaults.standard.set(self.OptimizationfromGraphEnd, forKey: "OptimizationfromGraphEnd")
        }
    }
    
    @Published var MaximumOdometryCacheSize: String {
        didSet {
            UserDefaults.standard.set(self.MaximumOdometryCacheSize, forKey: "MaximumOdometryCacheSize")
        }
    }
    
    @Published var GraphOptimizer: String {
        didSet {
            UserDefaults.standard.set(self.GraphOptimizer, forKey: "GraphOptimizer")
        }
    }
    
    @Published var ProximityDetection: String {
        didSet {
            UserDefaults.standard.set(self.ProximityDetection, forKey: "ProximityDetection")
        }
    }
    
    @Published var ArUcoMarkerDetection: Int {
        didSet {
            UserDefaults.standard.set(self.ArUcoMarkerDetection, forKey: "ArUcoMarkerDetection")
        }
    }
    
    @Published var MarkerDepthErrorEstimation: String {
        didSet {
            UserDefaults.standard.set(self.MarkerDepthErrorEstimation, forKey: "MarkerDepthErrorEstimation")
        }
    }
    
    @Published var MarkerSize : String {
        didSet {
            UserDefaults.standard.set(self.MarkerSize, forKey: "MarkerSize")
        }
    }
    
    // MARK: Rendering
    
    @Published var PointCloudDensity : Int {
        didSet {
            UserDefaults.standard.set(self.PointCloudDensity, forKey: "PointCloudDensity")
        }
    }
    
    @Published var MaxDepth : Float {
        didSet {
            UserDefaults.standard.set(self.MaxDepth, forKey: "MaxDepth")
        }
    }
    
    @Published var MinDepth : Float {
        didSet {
            UserDefaults.standard.set(self.MinDepth, forKey: "MinDepth")
        }
    }
    
    @Published var DepthConfidence : Int {
        didSet {
            UserDefaults.standard.set(self.DepthConfidence, forKey: "DepthConfidence")
        }
    }
    
    @Published var PointSize : Float {
        didSet {
            UserDefaults.standard.set(self.PointSize, forKey: "PointSize")
        }
    }
    
    @Published var MeshAngleTolerance : Float {
        didSet {
            UserDefaults.standard.set(self.MeshAngleTolerance, forKey: "MeshAngleTolerance")
        }
    }
    
    @Published var MeshTriangleSize : Int {
        didSet {
            UserDefaults.standard.set(self.MeshTriangleSize, forKey: "MarkMeshTriangleSizeerSize")
        }
    }
    
    @Published var MeshDecimationFactor : Float {
        didSet {
            UserDefaults.standard.set(self.MeshDecimationFactor, forKey: "MeshDecimationFactor")
        }
    }
    
    @Published var BackgroundColor : Float {
        didSet {
            UserDefaults.standard.set(self.BackgroundColor, forKey: "BackgroundColor")
        }
    }
    
    @Published var NoiseFilteringRatio : Float {
        didSet {
            UserDefaults.standard.set(self.NoiseFilteringRatio, forKey: "NoiseFilteringRatio")
        }
    }
    
    @Published var ColorCorrectionRadius : Float {
        didSet {
            UserDefaults.standard.set(self.ColorCorrectionRadius, forKey: "ColorCorrectionRadius")
        }
    }
    
    @Published var TextureResolution : Int {
        didSet {
            UserDefaults.standard.set(self.TextureResolution, forKey: "TextureResolution")
        }
    }
    
    @Published var SaveGPS : Bool {
        didSet {
            UserDefaults.standard.set(self.SaveGPS, forKey: "SaveGPS")
        }
    }
    
    private init() {
        
        // MARK: Update Preference init
        self.Blending = UserDefaults.standard.bool(forKey: "Bleeding")
        self.NodesFiltering = UserDefaults.standard.bool(forKey: "NodesFiltering")
        self.HDMode = UserDefaults.standard.bool(forKey: "HDMode")
        self.Smoothing = UserDefaults.standard.bool(forKey: "Smoothing")
        self.AppendMode = UserDefaults.standard.bool(forKey: "AppendMode")
        self.TimeLimit = UserDefaults.standard.string(forKey: "TimeLimit") ?? "0"
        self.mTimeThr = (UserDefaults.standard.string(forKey: "TimeLimit")! as NSString).integerValue
        self.mMaxFeatures = (UserDefaults.standard.string(forKey: "MaxFeaturesExtractedLoopClosure")! as NSString).integerValue
        
        // MARK: Mapping params init
        self.UpdateRate = UserDefaults.standard.string(forKey: "UpdateRate") ?? "0"
        self.MemoryLimit = UserDefaults.standard.string(forKey: "MemoryLimit") ?? "0"
        self.MaximumMotionSpeed = UserDefaults.standard.string(forKey: "MaximumMotionSpeed") ?? "0"
        self.motionSpeed  = (UserDefaults.standard.string(forKey: "MaximumMotionSpeed")! as NSString).floatValue / 2.0
        self.LoopClosureThreshold = UserDefaults.standard.string(forKey: "LoopClosureThreshold") ?? ""
        self.SimilarityThreshold = UserDefaults.standard.string(forKey: "SimilarityThreshold") ?? "1"
        self.MaxFeaturesExtractedLoopClosure = UserDefaults.standard.string(forKey: "MaxFeaturesExtractedLoopClosure") ?? "0"
        self.MaxFeaturesExtractedVocabulary = UserDefaults.standard.string(forKey: "MaxFeaturesExtractedVocabulary") ?? "1"
        self.MinInliers = UserDefaults.standard.string(forKey: "MinInliers") ?? "1"
        self.FeatureType = UserDefaults.standard.string(forKey: "FeatureType") ?? ""
        self.SaveAllFramesInDatabase = UserDefaults.standard.bool(forKey: "SaveAllFramesInDatabase")
        self.OptimizationfromGraphEnd = UserDefaults.standard.bool(forKey: "OptimizationfromGraphEnd")
        self.MaximumOdometryCacheSize = UserDefaults.standard.string(forKey: "MaximumOdometryCacheSize") ?? ""
        self.GraphOptimizer = UserDefaults.standard.string(forKey: "GraphOptimizer") ?? ""
        self.ProximityDetection = UserDefaults.standard.string(forKey: "ProximityDetection") ?? ""
        self.ArUcoMarkerDetection = UserDefaults.standard.integer(forKey: "ArUcoMarkerDetection")
        self.MarkerDepthErrorEstimation = UserDefaults.standard.string(forKey: "MarkerDepthErrorEstimation") ?? ""
        self.MarkerSize = UserDefaults.standard.string(forKey: "MarkerSize") ?? ""
        
        // MARK: Rendering init
        self.PointCloudDensity = UserDefaults.standard.integer(forKey: "PointCloudDensity")
        self.DepthConfidence = UserDefaults.standard.integer(forKey: "DepthConfidence")
        self.MeshTriangleSize = UserDefaults.standard.integer(forKey: "MeshTriangleSize")
        self.TextureResolution = UserDefaults.standard.integer(forKey: "TextureResolution")
        
        self.MaxDepth = UserDefaults.standard.float(forKey: "MaxDepth")
        self.MinDepth = UserDefaults.standard.float(forKey: "MinDepth")
        self.PointSize = UserDefaults.standard.float(forKey: "PointSize")
        self.MeshAngleTolerance = UserDefaults.standard.float(forKey: "MeshAngleTolerance")
        self.MeshDecimationFactor = UserDefaults.standard.float(forKey: "MeshDecimationFactor")
        self.BackgroundColor = UserDefaults.standard.float(forKey: "BackgroundColor")
        self.NoiseFilteringRatio = UserDefaults.standard.float(forKey: "NoiseFilteringRatio")
        self.ColorCorrectionRadius = UserDefaults.standard.float(forKey: "ColorCorrectionRadius")
        self.SaveGPS = UserDefaults.standard.bool(forKey: "SaveGPS")
        
    }
    
}
