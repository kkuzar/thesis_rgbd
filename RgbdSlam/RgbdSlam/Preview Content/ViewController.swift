//
//  ViewController.swift
//  GLKittutorial
//
//  Created by Mathieu Labbe on 2020-12-28.
//

import GLKit
import ARKit
import Zip
import StoreKit

extension Array {
    func size() -> Int {
        return MemoryLayout<Element>.stride * self.count
    }
}

class ViewController: GLKViewController, ARSessionDelegate, RTABMapObserver, UIPickerViewDataSource, UIPickerViewDelegate, CLLocationManagerDelegate {
    
    private let session = ARSession()
    private var locationManager: CLLocationManager?
    private var mLastKnownLocation: CLLocation?
    private var mLastLightEstimate: CGFloat?
    
    private var context: EAGLContext?
    private var rtabmap: RTABMap?
    
    private var databases = [URL]()
    private var currentDatabaseIndex: Int = 0
    private var openedDatabasePath: URL?
    
    private var progressDialog: UIAlertController?
    var progressView : UIProgressView?
    
    var maxPolygonsPickerView: UIPickerView!
    var maxPolygonsPickerData: [Int]!
    
    private var mTotalLoopClosures: Int = 0
    private var mMapNodes: Int = 0
    private var mTimeThr: Int = 0
    private var mMaxFeatures: Int = 0
    private var mLoopThr = 0.11
    
    private var mReviewRequested = false
    
    // UI states
    private enum State {
        case STATE_WELCOME,    // Camera/Motion off - showing only buttons open and start new scan
        STATE_CAMERA,          // Camera/Motion on - not mapping
        STATE_MAPPING,         // Camera/Motion on - mapping
        STATE_IDLE,            // Camera/Motion off
        STATE_PROCESSING,      // Camera/Motion off - post processing
        STATE_VISUALIZING,     // Camera/Motion off - Showing optimized mesh
        STATE_VISUALIZING_CAMERA,     // Camera/Motion on  - Showing optimized mesh
        STATE_VISUALIZING_WHILE_LOADING // Camera/Motion off - Loading data while showing optimized mesh
    }
    private var mState: State = State.STATE_WELCOME;
    private func getStateString(state: State) -> String {
        switch state {
        case .STATE_WELCOME:
            return "Welcome"
        case .STATE_CAMERA:
            return "Camera Preview"
        case .STATE_MAPPING:
            return "Mapping"
        case .STATE_PROCESSING:
            return "Processing"
        case .STATE_VISUALIZING:
            return "Visualizing"
        case .STATE_VISUALIZING_CAMERA:
            return "Visualizing with Camera"
        case .STATE_VISUALIZING_WHILE_LOADING:
            return "Visualizing while Loading"
        default: // IDLE
            return "Idle"
        }
    }
    
    private var depthSupported: Bool = false
    
    private var viewMode: Int = 2 // 0=Cloud, 1=Mesh, 2=Textured Mesh
    private var cameraMode: Int = 1
    
    private var statusShown: Bool = true
    private var debugShown: Bool = false
    private var mapShown: Bool = true
    private var odomShown: Bool = true
    private var graphShown: Bool = true
    private var gridShown: Bool = true
    private var optimizedGraphShown: Bool = true
    private var wireframeShown: Bool = false
    private var backfaceShown: Bool = false
    private var lightingShown: Bool = false
    private var mHudVisible: Bool = true
    private var mLastTimeHudShown: DispatchTime = .now()
    private var mMenuOpened: Bool = false
    
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var viewButton: UIButton!
    @IBOutlet weak var newScanButtonLarge: UIButton!
    @IBOutlet weak var libraryButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var closeVisualizationButton: UIButton!
    @IBOutlet weak var stopCameraButton: UIButton!
    @IBOutlet weak var exportOBJPLYButton: UIButton!
    @IBOutlet weak var orthoDistanceSlider: UISlider!{
        didSet{
            orthoDistanceSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
        }
    }
    @IBOutlet weak var orthoGridSlider: UISlider!
    @IBOutlet weak var toastLabel: UILabel!
    
    let RTABMAP_TMP_DB = "rtabmap.tmp.db"
    let RTABMAP_RECOVERY_DB = "rtabmap.tmp.recovery.db"
    let RTABMAP_EXPORT_DIR = "Export"

    
    func showToast(message : String, seconds: Double){
        if(!self.toastLabel.isHidden)
        {
            return;
        }
        self.toastLabel.text = message
        self.toastLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            self.toastLabel.isHidden = true
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.toastLabel.isHidden = true
        session.delegate = self
        
        depthSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        
        rtabmap = RTABMap()
        rtabmap?.setupCallbacksWithCPP()
        
        context = EAGLContext(api: .openGLES2)
        EAGLContext.setCurrent(context)
        
        if let view = self.view as? GLKView, let context = context {
            view.context = context
            delegate = self
            rtabmap?.initGlContent()
        }
        
        menuButton.showsMenuAsPrimaryAction = true
        viewButton.showsMenuAsPrimaryAction = true
        statusLabel.numberOfLines = 0
        statusLabel.text = ""
        
        updateDatabases()
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped(_:)))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
//        let notificationCenter = NotificationCenter.default
//        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
//        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
//        notificationCenter.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        
        rtabmap!.addObserver(self)
        
        registerSettingsBundle()
        updateDisplayFromDefaults()
        
        maxPolygonsPickerView = UIPickerView(frame: CGRect(x: 10, y: 50, width: 250, height: 150))
        maxPolygonsPickerView.delegate = self
        maxPolygonsPickerView.dataSource = self

        // This is where you can set your min/max values
        let minNum = 0
        let maxNum = 9
        maxPolygonsPickerData = Array(stride(from: minNum, to: maxNum + 1, by: 1))
        
        orthoDistanceSlider.setValue(80, animated: false)
        orthoGridSlider.setValue(90, animated: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateState(state: self.mState)
        }
    }
        
    func statsUpdated(_ rtabmap: RTABMap,
                           nodes: Int,
                           words: Int,
                           points: Int,
                           polygons: Int,
                           updateTime: Float,
                           loopClosureId: Int,
                           highestHypId: Int,
                           databaseMemoryUsed: Int,
                           inliers: Int,
                           matches: Int,
                           featuresExtracted: Int,
                           hypothesis: Float,
                           nodesDrawn: Int,
                           fps: Float,
                           rejected: Int,
                           rehearsalValue: Float,
                           optimizationMaxError: Float,
                           optimizationMaxErrorRatio: Float,
                           distanceTravelled: Float,
                           fastMovement: Int,
                           landmarkDetected: Int,
                           x: Float,
                           y: Float,
                           z: Float,
                           roll: Float,
                           pitch: Float,
                           yaw: Float)
    {
        let usedMem = self.getMemoryUsage()
        
        if(loopClosureId > 0)
        {
            mTotalLoopClosures += 1;
        }
        let previousNodes = mMapNodes
        mMapNodes = nodes;
        
        let formattedDate = Date().getFormattedDate(format: "HH:mm:ss.SSS")
        
        DispatchQueue.main.async {
            
            if(self.mMapNodes>0 && previousNodes==0 && self.mState != .STATE_MAPPING)
            {
                self.updateState(state: self.mState) // refesh menus and actions
            }
            
            self.statusLabel.text = ""
            if self.statusShown {
                self.statusLabel.text =
                    self.statusLabel.text! +
                    "Status: \(self.getStateString(state: self.mState))\n" +
                    "Memory Usage : \(usedMem) MB"
            }
            if self.debugShown {
                self.statusLabel.text =
                    self.statusLabel.text! + "\n"
                var gpsString = "\n"
                if(UserDefaults.standard.bool(forKey: "SaveGPS"))
                {
                    if(self.mLastKnownLocation != nil)
                    {
                        let secondsOld = (Date().timeIntervalSince1970 - self.mLastKnownLocation!.timestamp.timeIntervalSince1970)
                        var bearing = 0.0
                        if(self.mLastKnownLocation!.course > 0.0) {
                            bearing = self.mLastKnownLocation!.course
                            
                        }
                        gpsString = String(format: "GPS: %.2f %.2f %.2fm %ddeg %.0fm [%d sec old]\n",
                                           self.mLastKnownLocation!.coordinate.longitude,
                                           self.mLastKnownLocation!.coordinate.latitude,
                                           self.mLastKnownLocation!.altitude,
                                           Int(bearing),
                                           self.mLastKnownLocation!.horizontalAccuracy,
                                           Int(secondsOld));
                    }
                    else
                    {
                        gpsString = "GPS: [not yet available]\n";
                    }
                }
                var lightString = "\n"
                if(self.mLastLightEstimate != nil)
                {
                    lightString = String("Light (lm): \(Int(self.mLastLightEstimate!))\n")
                }
                
                self.statusLabel.text =
                    self.statusLabel.text! +
                    gpsString + //gps
                    lightString + //env sensors
                    "Time: \(formattedDate)\n" +
                    "Nodes (WM): \(nodes) (\(nodesDrawn) shown)\n" +
                    "Words: \(words)\n" +
                    "Database (MB): \(databaseMemoryUsed)\n" +
                    "Number of points: \(points)\n" +
                    "Polygons: \(polygons)\n" +
                    "Update time (ms): \(Int(updateTime)) / \(self.mTimeThr==0 ? "No Limit" : String(self.mTimeThr))\n" +
                    "Features: \(featuresExtracted) / \(self.mMaxFeatures==0 ? "No Limit" : (self.mMaxFeatures == -1 ? "Disabled" : String(self.mMaxFeatures)))\n" +
                    "Rehearsal (%): \(Int(rehearsalValue*100))\n" +
                    "Loop closures: \(self.mTotalLoopClosures)\n" +
                    "Inliers: \(inliers)\n" +
                    "Hypothesis (%): \(Int(hypothesis*100)) / \(Int(self.mLoopThr*100)) (\(loopClosureId>0 ? loopClosureId : highestHypId))\n" +
                    String(format: "FPS (rendering): %.1f Hz\n", fps) +
                    String(format: "Travelled distance: %.2f m\n", distanceTravelled) +
                    String(format: "Pose (x,y,z): %.2f %.2f %.2f", x, y, z)
            }
            if(self.mState == .STATE_MAPPING || self.mState == .STATE_VISUALIZING_CAMERA)
            {
                if(loopClosureId > 0) {
                    if(self.mState == .STATE_VISUALIZING_CAMERA) {
                        self.showToast(message: "Localized!", seconds: 1);
                    }
                    else {
                        self.showToast(message: "Loop closure detected!", seconds: 1);
                    }
                }
                else if(rejected > 0)
                {
                    if(inliers >= UserDefaults.standard.integer(forKey: "MinInliers"))
                    {
                        if(optimizationMaxError > 0.0)
                        {
                            self.showToast(message: String(format: "Loop closure rejected, too high graph optimization error (%.3fm: ratio=%.3f < factor=%.1fx).", optimizationMaxError, optimizationMaxErrorRatio, UserDefaults.standard.float(forKey: "MaxOptimizationError")), seconds: 1);
                        }
                        else
                        {
                            self.showToast(message: String(format: "Loop closure rejected, graph optimization failed! You may try a different Graph Optimizer (see Mapping options)."), seconds: 1);
                        }
                    }
                    else
                    {
                        self.showToast(message: String(format: "Loop closure rejected, not enough inliers (%d/%d < %d).", inliers, matches, UserDefaults.standard.integer(forKey: "MinInliers")), seconds: 1);
                    }
                }
                else if(landmarkDetected > 0) {
                    self.showToast(message: "Landmark \(landmarkDetected) detected!", seconds: 1);
                }
            }
        }
    }
    
    
    func startCamera()
    {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                print("Start Camera")
                rtabmap!.startCamera()
                let configuration = ARWorldTrackingConfiguration()
                var message = ""
                if(!UserDefaults.standard.bool(forKey: "LidarMode"))
                {
                    message = "LiDAR is disabled (Settings->Mapping->LiDAR Mode = OFF), only tracked features will be mapped."
                    self.setMeshRendering(viewMode: 0)
                }
                else if !depthSupported
                {
                    message = "The device does not have a LiDAR, only tracked features will be mapped. A LiDAR is required for accurate 3D reconstruction."
                    self.setMeshRendering(viewMode: 0)
                }
                else
                {
                    configuration.frameSemantics = .sceneDepth
                }
                
                session.run(configuration, options: [.resetSceneReconstruction, .resetTracking, .removeExistingAnchors])
                
                switch mState {
                case .STATE_VISUALIZING:
                    updateState(state: .STATE_VISUALIZING_CAMERA)
                default:
                    locationManager?.startUpdatingLocation()
                    updateState(state: .STATE_CAMERA)
                }
                
                if(!message.isEmpty)
                {
                    let alertController = UIAlertController(title: "Start Camera", message: message, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
                    }
                    alertController.addAction(okAction)
                    present(alertController, animated: true)
                }
            
            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.async {
                            self.startCamera()
                        }
                    }
                }
            
        default:
            let alertController = UIAlertController(title: "Camera Disabled", message: "Camera permission is required to start the camera. You can enable it in Settings.", preferredStyle: .alert)

            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
            }
            alertController.addAction(settingsAction)
            
            let okAction = UIAlertAction(title: "Ignore", style: .default) { (action) in
            }
            alertController.addAction(okAction)
            
            present(alertController, animated: true)
        }
    }
    
    private func updateState(state: State)
    {
        print("State: \(state)")
        
        if(mState != state)
        {
            mState = state;
            resetNoTouchTimer(true)
            return
        }
        
        mState = state;

        var actionNewScanEnabled: Bool
        var actionSaveEnabled: Bool
        var actionResumeEnabled: Bool
        var actionExportEnabled: Bool
        var actionOptimizeEnabled: Bool
        var actionSettingsEnabled: Bool
        
        switch mState {
        case .STATE_CAMERA:
            libraryButton.isEnabled = false
            libraryButton.isHidden = false
            menuButton.isHidden = false
            viewButton.isHidden = false
            newScanButtonLarge.isHidden = true // WELCOME button
            recordButton.isHidden = false
            stopButton.isHidden = true
            closeVisualizationButton.isHidden = true
            stopCameraButton.isHidden = false
            exportOBJPLYButton.isHidden = true
            orthoDistanceSlider.isHidden = cameraMode != 3
            orthoGridSlider.isHidden = cameraMode != 3
            actionNewScanEnabled = true
            actionSaveEnabled = false
            actionResumeEnabled = false
            actionExportEnabled = false
            actionOptimizeEnabled = false
            actionSettingsEnabled = false
        case .STATE_MAPPING:
            libraryButton.isEnabled = false
            libraryButton.isHidden = !mHudVisible
            menuButton.isHidden = !mHudVisible
            viewButton.isHidden = !mHudVisible
            newScanButtonLarge.isHidden = true // WELCOME button
            recordButton.isHidden = true
            stopButton.isHidden = false
            closeVisualizationButton.isHidden = true
            stopCameraButton.isHidden = true
            exportOBJPLYButton.isHidden = true
            orthoDistanceSlider.isHidden = cameraMode != 3 || !mHudVisible
            orthoGridSlider.isHidden = cameraMode != 3 || !mHudVisible
            actionNewScanEnabled = true
            actionSaveEnabled = false
            actionResumeEnabled = false
            actionExportEnabled = false
            actionOptimizeEnabled = false
            actionSettingsEnabled = false
        case .STATE_PROCESSING,
             .STATE_VISUALIZING_WHILE_LOADING,
             .STATE_VISUALIZING_CAMERA:
            libraryButton.isEnabled = false
            libraryButton.isHidden = !mHudVisible
            menuButton.isHidden = !mHudVisible
            viewButton.isHidden = !mHudVisible
            newScanButtonLarge.isHidden = true // WELCOME button
            recordButton.isHidden = true
            stopButton.isHidden = true
            closeVisualizationButton.isHidden = true
            stopCameraButton.isHidden = mState != .STATE_VISUALIZING_CAMERA
            exportOBJPLYButton.isHidden = true
            orthoDistanceSlider.isHidden = cameraMode != 3 || mState != .STATE_VISUALIZING_WHILE_LOADING
            orthoGridSlider.isHidden = cameraMode != 3 || mState != .STATE_VISUALIZING_WHILE_LOADING
            actionNewScanEnabled = false
            actionSaveEnabled = false
            actionResumeEnabled = false
            actionExportEnabled = false
            actionOptimizeEnabled = false
            actionSettingsEnabled = false
        case .STATE_VISUALIZING:
            libraryButton.isEnabled = !databases.isEmpty
            libraryButton.isHidden = !mHudVisible
            menuButton.isHidden = !mHudVisible
            viewButton.isHidden = !mHudVisible
            newScanButtonLarge.isHidden = true // WELCOME button
            recordButton.isHidden = true
            stopButton.isHidden = true
            closeVisualizationButton.isHidden = !mHudVisible
            stopCameraButton.isHidden = true
            exportOBJPLYButton.isHidden = !mHudVisible
            orthoDistanceSlider.isHidden = cameraMode != 3 || !mHudVisible
            orthoGridSlider.isHidden = cameraMode != 3 || !mHudVisible
            actionNewScanEnabled = true
            actionSaveEnabled = mMapNodes>0
            actionResumeEnabled = mMapNodes>0
            actionExportEnabled = mMapNodes>0
            actionOptimizeEnabled = mMapNodes>0
            actionSettingsEnabled = true
        default: // IDLE // WELCOME
            libraryButton.isEnabled = !databases.isEmpty
            libraryButton.isHidden = mState != .STATE_WELCOME && !mHudVisible
            menuButton.isHidden = mState != .STATE_WELCOME && !mHudVisible
            viewButton.isHidden = mState != .STATE_WELCOME && !mHudVisible
            newScanButtonLarge.isHidden = mState != .STATE_WELCOME
            recordButton.isHidden = true
            stopButton.isHidden = true
            closeVisualizationButton.isHidden = true
            stopCameraButton.isHidden = true
            exportOBJPLYButton.isHidden = true
            orthoDistanceSlider.isHidden = cameraMode != 3 || !mHudVisible
            orthoGridSlider.isHidden = cameraMode != 3 || !mHudVisible
            actionNewScanEnabled = true
            actionSaveEnabled = mState != .STATE_WELCOME && mMapNodes>0
            actionResumeEnabled = mState != .STATE_WELCOME && mMapNodes>0
            actionExportEnabled = mState != .STATE_WELCOME && mMapNodes>0
            actionOptimizeEnabled = mState != .STATE_WELCOME && mMapNodes>0
            actionSettingsEnabled = true
        }

        let view = self.view as? GLKView
        if(mState != .STATE_MAPPING && mState != .STATE_CAMERA && mState != .STATE_VISUALIZING_CAMERA)
        {
            self.isPaused = true
            view?.enableSetNeedsDisplay = true
            self.view.setNeedsDisplay()
            print("enableSetNeedsDisplay")
        }
        else
        {
            view?.enableSetNeedsDisplay = false
            self.isPaused = false
            print("diaableSetNeedsDisplay")
        }
        
        if !self.isPaused {
            self.view.setNeedsDisplay()
        }
        
        // Update menus based on current state
        
        // PointCloud menu
        let pointCloudMenu = UIMenu(title: "Point cloud...", children: [
            UIAction(title: "Current Density", handler: { _ in
                self.export(isOBJ: false, meshing: false, regenerateCloud: false, optimized: false, optimizedMaxPolygons: 0, previousState: self.mState)
            }),
            UIAction(title: "Max Density", handler: { _ in
                self.export(isOBJ: false, meshing: false, regenerateCloud: true, optimized: false, optimizedMaxPolygons: 0, previousState: self.mState)
            })
        ])
        // Optimized Mesh menu
        let optimizedMeshMenu = UIMenu(title: "Optimized mesh...", children: [
            UIAction(title: "Colored Mesh", handler: { _ in
                self.exportMesh(isOBJ: false)
            }),
            UIAction(title: "Textured Mesh", handler: { _ in
                self.exportMesh(isOBJ: true)
            })
        ])
        
        // Export menu
        let exportMenu = UIMenu(title: "Assemble...", children: [pointCloudMenu, optimizedMeshMenu])
        
        // Optimized Mesh menu
        let optimizeAdvancedMenu = UIMenu(title: "Advanced...", children: [
            UIAction(title: "Global Graph Optimization", handler: { _ in
                self.optimization(approach: 0)
            }),
            UIAction(title: "Detect More Loop Closures", handler: { _ in
                self.optimization(approach: 2)
            }),
            UIAction(title: "Adjust Colors (Fast)", handler: { _ in
                self.optimization(approach: 5)
            }),
            UIAction(title: "Adjust Colors (Full)", handler: { _ in
                self.optimization(approach: 6)
            }),
            UIAction(title: "Mesh Smoothing", handler: { _ in
                self.optimization(approach: 7)
            }),
            UIAction(title: "Bundle Adjustment", handler: { _ in
                self.optimization(approach: 1)
            }),
            UIAction(title: "Noise Filtering", handler: { _ in
                self.optimization(approach: 4)
            })
        ])
        
        // Optimize menu
        let optimizeMenu = UIMenu(title: "Optimize...", children: [
            UIAction(title: "Standard Optimization", handler: { _ in
                self.optimization(approach: -1)
            }),
            optimizeAdvancedMenu])
                
        var fileMenuChildren: [UIMenuElement] = []
        fileMenuChildren.append(UIAction(title: "New Scan", image: UIImage(systemName: "plus.app"), attributes: actionNewScanEnabled ? [] : .disabled, state: .off, handler: { _ in
            self.newScan()
        }))
        if(actionOptimizeEnabled) {
            fileMenuChildren.append(optimizeMenu)
        }
        else {
            fileMenuChildren.append(UIAction(title: "Optimize...", attributes: .disabled, state: .off, handler: { _ in
            }))
        }
        if(actionExportEnabled) {
            fileMenuChildren.append(exportMenu)
        }
        else {
            fileMenuChildren.append(UIAction(title: "Assemble...", attributes: .disabled, state: .off, handler: { _ in
            }))
        }
        fileMenuChildren.append(UIAction(title: "Save", image: UIImage(systemName: "square.and.arrow.down"), attributes: actionSaveEnabled ? [] : .disabled, state: .off, handler: { _ in
            self.save()
        }))
        fileMenuChildren.append(UIAction(title: "Append Scan", image: UIImage(systemName: "play.fill"), attributes: actionResumeEnabled ? [] : .disabled, state: .off, handler: { _ in
            self.resumeScan()
        }))
        
        // File menu
        let fileMenu = UIMenu(title: "File", options: .displayInline, children: fileMenuChildren)
        
        // Visibility menu
        let visibilityMenu = UIMenu(title: "Visibility...", children: [
            UIAction(title: "Status", image: statusShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: (self.mState != .STATE_WELCOME) ? [] : .disabled, handler: { _ in
                self.statusShown = !self.statusShown
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Debug", image: debugShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: (self.mState != .STATE_WELCOME) ? [] : .disabled, handler: { _ in
                self.debugShown = !self.debugShown
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Odom Visible", image: odomShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: (self.mState == .STATE_MAPPING || self.mState == .STATE_CAMERA || self.mState == .STATE_VISUALIZING_CAMERA) ? [] : .disabled, handler: { _ in
                self.odomShown = !self.odomShown
                self.rtabmap!.setOdomCloudShown(shown: self.odomShown)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Graph Visibile", image: graphShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: (self.mState == .STATE_MAPPING || self.mState == .STATE_CAMERA || self.mState == .STATE_IDLE) ? [] : .disabled, handler: { _ in
                self.graphShown = !self.graphShown
                self.rtabmap!.setGraphVisible(visible: self.graphShown)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Grid Visible", image: gridShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), handler: { _ in
                self.gridShown = !self.gridShown
                self.rtabmap!.setGridVisible(visible: self.gridShown)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Optimized Graph", image: optimizedGraphShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: (self.mState == .STATE_IDLE) ? [] : .disabled, handler: { _ in
                self.optimizedGraphShown = !self.optimizedGraphShown
                self.rtabmap!.setGraphOptimization(enabled: self.optimizedGraphShown)
                self.resetNoTouchTimer(true)
            })
        ])
        
        let settingsMenu = UIMenu(title: "Settings", options: .displayInline, children: [visibilityMenu,
            UIAction(title: "Settings", image: UIImage(systemName: "gearshape.2"), attributes: actionSettingsEnabled ? [] : .disabled, state: .off, handler: { _ in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }

                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
            }),
            UIAction(title: "Restore All Default Settings", attributes: actionSettingsEnabled ? [] : .disabled, state: .off, handler: { _ in
                
                let ac = UIAlertController(title: "Reset All Default Settings", message: "Do you want to reset all settings to default?", preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                    let notificationCenter = NotificationCenter.default
                    notificationCenter.removeObserver(self)
                    UserDefaults.standard.reset()
                    self.registerSettingsBundle()
                    self.updateDisplayFromDefaults();
                    notificationCenter.addObserver(self, selector: #selector(self.defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
                }))
                ac.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                self.present(ac, animated: true)
             })
        ])

        menuButton.menu = UIMenu(title: "", children: [fileMenu, settingsMenu])
        menuButton.addTarget(self, action: #selector(ViewController.menuOpened(_:)), for: .menuActionTriggered)
        
        // Camera menu
        let renderingMenu = UIMenu(title: "Rendering", options: .displayInline, children: [
            UIAction(title: "Wireframe", image: self.wireframeShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), handler: { _ in
                self.wireframeShown = !self.wireframeShown
                self.rtabmap!.setWireframe(enabled: self.wireframeShown)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Lighting", image: self.lightingShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: self.mState == .STATE_VISUALIZING || self.mState == .STATE_VISUALIZING_CAMERA || self.mState == .STATE_VISUALIZING_WHILE_LOADING ? [] : .disabled, handler: { _ in
                self.lightingShown = !self.lightingShown
                self.rtabmap!.setLighting(enabled: self.lightingShown)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Backface", image: self.backfaceShown ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), handler: { _ in
                self.backfaceShown = !self.backfaceShown
                self.rtabmap!.setBackfaceCulling(enabled: !self.backfaceShown)
                self.resetNoTouchTimer(true)
            })
        ])
        
        let cameraMenu = UIMenu(title: "View", options: .displayInline, children: [
            UIAction(title: "First-P. View", image: cameraMode == 0 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: (self.mState == .STATE_CAMERA || self.mState == .STATE_VISUALIZING || self.mState == .STATE_MAPPING || self.mState == .STATE_VISUALIZING_CAMERA) ? [] : .disabled, handler: { _ in
                self.setGLCamera(type: 0)
                if(self.mState == .STATE_VISUALIZING)
                {
                    self.rtabmap?.setLocalizationMode(enabled: true)
                    self.rtabmap?.setPausedMapping(paused: false);
                    self.startCamera()
                    self.updateState(state: .STATE_VISUALIZING_CAMERA)
                }
                else
                {
                    self.resetNoTouchTimer(true)
                }
            }),
            UIAction(title: "Third-P. View", image: cameraMode == 1 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), handler: { _ in
                self.setGLCamera(type: 1)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Top View", image: cameraMode == 2 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), handler: { _ in
                self.setGLCamera(type: 2)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Ortho View", image: cameraMode == 3 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), handler: { _ in
                self.setGLCamera(type: 3)
                self.resetNoTouchTimer(true)
            })
        ])
        
        let showCloudMeshActions = mState != .STATE_VISUALIZING && mState != .STATE_VISUALIZING_CAMERA && mState != .STATE_PROCESSING && mState != .STATE_VISUALIZING_WHILE_LOADING
        let cloudMeshMenu = UIMenu(title: "CloudMesh", options: .displayInline, children: [
            UIAction(title: "Point Cloud", image: viewMode == 0 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: showCloudMeshActions ? [] : .disabled, handler: { _ in
                self.setMeshRendering(viewMode: 0)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Mesh", image: viewMode == 1 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: showCloudMeshActions ? [] : .disabled, handler: { _ in
                self.setMeshRendering(viewMode: 1)
                self.resetNoTouchTimer(true)
            }),
            UIAction(title: "Texture Mesh", image: viewMode == 2 ? UIImage(systemName: "checkmark.circle") : UIImage(systemName: "circle"), attributes: showCloudMeshActions ? [] : .disabled, handler: { _ in
                self.setMeshRendering(viewMode: 2)
                self.resetNoTouchTimer(true)
            })
        ])

        var viewMenuChildren: [UIMenuElement] = []
        viewMenuChildren.append(cameraMenu)
        viewMenuChildren.append(renderingMenu)
        viewMenuChildren.append(cloudMeshMenu)
        viewButton.menu = UIMenu(title: "", children: viewMenuChildren)
        viewButton.addTarget(self, action: #selector(ViewController.menuOpened(_:)), for: .menuActionTriggered)
    }
    
    @IBAction func menuOpened(_ sender:UIButton)
    {
        mMenuOpened = true;
    }
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return maxPolygonsPickerData.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if(row == 0)
        {
            return "No Limit"
        }
        return "\(maxPolygonsPickerData[row])00 000"
    }
    
    //This is called when a new frame has been updated.
    func session(_ session: ARSession, didUpdate frame: ARFrame)
    {
        var status = ""
        var accept = false
        
        switch frame.camera.trackingState {
        case .normal:
            accept = true
        case .notAvailable:
            status = "Tracking not available"
        case .limited(.excessiveMotion):
            accept = true
            status = "Please Slow Your Movement"
        case .limited(.insufficientFeatures):
            accept = true
            status = "Avoid Featureless Surfaces"
        case .limited(.initializing):
            status = "Initializing"
        case .limited(.relocalizing):
            status = "Relocalizing"
        default:
            status = "Unknown tracking state"
        }
        
        mLastLightEstimate = frame.lightEstimate?.ambientIntensity
        
        if !status.isEmpty && mLastLightEstimate != nil && mLastLightEstimate! < 100 && accept {
            status = "Camera Is Occluded Or Lighting Is Too Dark"
        }

        if accept
        {
            if let rotation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
            {
                rtabmap?.postOdometryEvent(frame: frame, orientation: rotation, viewport: self.view.frame.size)
            }
        }
        else
        {
            rtabmap?.notifyLost();
        }
        
        if !status.isEmpty {
            DispatchQueue.main.async {
                self.showToast(message: status, seconds: 2)
            }
        }
    }
    
    // This is called when a session fails.
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                if let configuration = self.session.configuration {
                    self.session.run(configuration, options: [.resetSceneReconstruction, .resetTracking, .removeExistingAnchors])
                }
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        mLastKnownLocation = locations.last!
        rtabmap?.setGPS(location: locations.last!);
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print(error)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
    {
        print(status.rawValue)
        if(status == .notDetermined)
        {
            locationManager?.requestWhenInUseAuthorization()
        }
        if(status == .denied)
        {
            let alertController = UIAlertController(title: "GPS Disabled", message: "GPS option is enabled (Settings->Mapping...) but localization is denied for this App. To enable location for this App, go in Settings->Privacy->Location.", preferredStyle: .alert)

            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
                self.locationManager = nil
                self.mLastKnownLocation = nil
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }

                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
            }
            alertController.addAction(settingsAction)
            
            let okAction = UIAlertAction(title: "Turn Off GPS", style: .default) { (action) in
                UserDefaults.standard.setValue(false, forKey: "SaveGPS")
                self.updateDisplayFromDefaults()
            }
            alertController.addAction(okAction)
            
            present(alertController, animated: true)
        }
        else if(status == .authorizedWhenInUse)
        {
            if locationManager != nil {
                if(locationManager!.accuracyAuthorization == .reducedAccuracy) {
                    let alertController = UIAlertController(title: "GPS Reduced Accuracy", message: "Your location settings for this App is set to reduced accuracy. We recommend to use high accuracy.", preferredStyle: .alert)

                    let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
                        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }

                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                                print("Settings opened: \(success)") // Prints true
                            })
                        }
                    }
                    alertController.addAction(settingsAction)
                    
                    let okAction = UIAlertAction(title: "Ignore", style: .default) { (action) in
                    }
                    alertController.addAction(okAction)
                    
                    present(alertController, animated: true)
                }
            }
        }
    }
    
    var statusBarOrientation: UIInterfaceOrientation? {
        get {
            guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else {
                #if DEBUG
                fatalError("Could not obtain UIInterfaceOrientation from a valid windowScene")
                #else
                return nil
                #endif
            }
            return orientation
        }
    }
        
    deinit {
        EAGLContext.setCurrent(context)
        rtabmap = nil
        context = nil
        EAGLContext.setCurrent(nil)
    }

    
    func registerSettingsBundle(){
        let appDefaults = [String:AnyObject]()
        UserDefaults.standard.register(defaults: appDefaults)
    }
    



    //MARK: Actions   
    @IBAction func stopAction(_ sender: UIButton) {
        stopMapping(ignoreSaving: false)
    }

    @IBAction func recordAction(_ sender: UIButton) {
        rtabmap?.setPausedMapping(paused: false);
        updateState(state: .STATE_MAPPING)
    }
    
    @IBAction func newScanAction(_ sender: UIButton) {
        newScan()
    }
    
    @IBAction func closeVisualizationAction(_ sender: UIButton) {
        closeVisualization()
        rtabmap!.postExportation(visualize: false)
    }
    
    @IBAction func stopCameraAction(_ sender: UIButton) {
        appMovedToBackground();
    }
    
    @IBAction func exportOBJPLYAction(_ sender: UIButton) {
        exportOBJPLY()
    }
    
    @IBAction func libraryAction(_ sender: UIButton) {
        openLibrary();
    }
    @IBAction func rotateGridAction(_ sender: UISlider) {
        rtabmap!.setGridRotation((Float(sender.value)-90.0)/2.0)
        self.view.setNeedsDisplay()
    }
    @IBAction func clipDistanceAction(_ sender: UISlider) {
        rtabmap!.setOrthoCropFactor(Float(120-sender.value)/20.0 - 3.0)
        self.view.setNeedsDisplay()
    }
}


extension ViewController: GLKViewControllerDelegate {
    
    // OPENGL UPDATE
    func glkViewControllerUpdate(_ controller: GLKViewController) {
        
    }
    
    // OPENGL DRAW
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        if let rotation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation
        {
            let viewportSize = CGSize(width: rect.size.width * view.contentScaleFactor, height: rect.size.height * view.contentScaleFactor)
            rtabmap?.setupGraphic(size: viewportSize, orientation: rotation)
        }
        
        let value = rtabmap?.render()
        
        DispatchQueue.main.async {
            if(value != 0 && self.progressView != nil)
            {
                print("Render dismissing")
                self.dismiss(animated: true)
                self.progressView = nil
            }
            if(value == -1)
            {
                self.showToast(message: "Out of Memory!", seconds: 2)
            }
            else if(value == -2)
            {
                self.showToast(message: "Rendering Error!", seconds: 2)
            }
        }
    }
}
