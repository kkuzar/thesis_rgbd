//
//  RgbdCamptureGLKView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 14.4.2024.
//

import SwiftUI
import GLKit
import ARKit
import StoreKit

struct RGBDCaptureViewControllerWrapper: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> some GLKViewController {
        return RGBDCaptureViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Update the controller when your app's state changes, if necessary.
    }
}

class RGBDCaptureViewController: GLKViewController, ARSessionDelegate, RTABMapObserver, UIPickerViewDataSource, UIPickerViewDelegate, CLLocationManagerDelegate {
    
    enum State {
        case STATE_WELCOME,    // Camera/Motion off - showing only buttons open and start new scan
             STATE_CAMERA,          // Camera/Motion on - not mapping
             STATE_MAPPING,         // Camera/Motion on - mapping
             STATE_IDLE,            // Camera/Motion off
             STATE_PROCESSING,      // Camera/Motion off - post processing
             STATE_VISUALIZING,     // Camera/Motion off - Showing optimized mesh
             STATE_VISUALIZING_CAMERA,     // Camera/Motion on  - Showing optimized mesh
             STATE_VISUALIZING_WHILE_LOADING // Camera/Motion off - Loading data while showing optimized mesh
    }
    
    
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
    
    let RTABMAP_TMP_DB = "rtabmap.tmp.db"
    let RTABMAP_RECOVERY_DB = "rtabmap.tmp.recovery.db"
    let RTABMAP_EXPORT_DIR = "Export"
    
    lazy var testBtn : UIButton = {
        let btn = UIButton(type: .roundedRect)
        btn.setTitle("Scan", for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private var labelTest: UILabel!
    
    lazy var toastLabel: UILabel = {
        let lbl = UILabel()
        return lbl
    }()
    
    let centerButton = UIButton()
    let topRightButton = UIButton()
    let bottomRightButton = UIButton()
    let bottomCenterButton = UIButton()
    
    // MARK: Functions
    
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
    
    //        @objc func appMovedToBackground() {
    //            if(mState == .STATE_VISUALIZING_CAMERA || mState == .STATE_MAPPING || mState == .STATE_CAMERA)
    //            {
    //                stopMapping(ignoreSaving: true)
    //            }
    //        }
    //
    //        @objc func appMovedToForeground() {
    //            updateDisplayFromDefaults()
    //
    //            if(mMapNodes > 0 && self.openedDatabasePath == nil)
    //            {
    //                let msg = "RTAB-Map has been pushed to background while mapping. Do you want to save the map now?"
    //                let alert = UIAlertController(title: "Mapping Stopped!", message: msg, preferredStyle: .alert)
    //                let alertActionNo = UIAlertAction(title: "Ignore", style: .cancel) {
    //                    (UIAlertAction) -> Void in
    //                }
    //                alert.addAction(alertActionNo)
    //                let alertActionYes = UIAlertAction(title: "Yes", style: .default) {
    //                    (UIAlertAction) -> Void in
    //                    self.save()
    //                }
    //                alert.addAction(alertActionYes)
    //                self.present(alert, animated: true, completion: nil)
    //            }
    //        }
    
    func getDocumentDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func getTmpDirectory() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }
    
    func setMeshRendering(viewMode: Int)
    {
        switch viewMode {
        case 0:
            self.rtabmap?.setMeshRendering(enabled: false, withTexture: false)
        case 1:
            self.rtabmap?.setMeshRendering(enabled: true, withTexture: false)
        default:
            self.rtabmap?.setMeshRendering(enabled: true, withTexture: true)
        }
        self.viewMode = viewMode
        updateState(state: mState)
    }
    
    func resetNoTouchTimer(_ showHud: Bool = false) {
        if(showHud)
        {
            print("Show HUD")
            mMenuOpened = false
            mHudVisible = true
            setNeedsStatusBarAppearanceUpdate()
            updateState(state: self.mState)
            
            mLastTimeHudShown = DispatchTime.now()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
                if(DispatchTime.now() <= self.mLastTimeHudShown + 4.9) {
                    return
                }
                if(self.mState != .STATE_WELCOME && self.mState != .STATE_CAMERA && self.presentedViewController as? UIAlertController == nil && !self.mMenuOpened)
                {
                    print("Hide HUD")
                    self.mHudVisible = false
                    self.setNeedsStatusBarAppearanceUpdate()
                    self.updateState(state: self.mState)
                }
            }
        }
        else if(mState != .STATE_WELCOME && mState != .STATE_CAMERA && presentedViewController as? UIAlertController == nil && !mMenuOpened)
        {
            print("Hide HUD")
            self.mHudVisible = false
            self.setNeedsStatusBarAppearanceUpdate()
            self.updateState(state: self.mState)
        }
    }
    
    func getMemoryUsage() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return taskInfo.resident_size / (1024*1024)
        }
        else {
            print("Error with task_info(): " +
                  (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
            return 0
        }
    }
    
    func registerSettingsBundle(){
        let appDefaults = [String:AnyObject]()
        UserDefaults.standard.register(defaults: appDefaults)
    }
    
    func setGLCamera(type: Int)
    {
        cameraMode = type
        rtabmap!.setCamera(type: type);
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
    
    // MARK: Camera Actions
    
    func closeVisualization()
    {
        updateState(state: .STATE_IDLE);
    }
    
    func newScan()
    {
        //        print("databases.size() = \(databases.size())")
        //        if(databases.count >= 5 && !mReviewRequested && self.depthSupported)
        //        {
        //            SKStoreReviewController.requestReviewInCurrentScene()
        //            mReviewRequested = true
        //        }
        
        if(mState == State.STATE_VISUALIZING)
        {
            closeVisualization()
        }
        
        mMapNodes = 0;
        self.openedDatabasePath = nil
        //let tmpDatabase = self.getDocumentDirectory().appendingPathComponent(self.RTABMAP_TMP_DB)
        let inMemory = UserDefaults.standard.bool(forKey: "DatabaseInMemory")
        //        if(!(self.mState == State.STATE_CAMERA || self.mState == State.STATE_MAPPING) &&
        //           FileManager.default.fileExists(atPath: tmpDatabase.path) &&
        //           tmpDatabase.fileSize > 1024*1024) // > 1MB
        //        {
        //            dismiss(animated: true, completion: {
        //                let msg = "The previous session (\(tmpDatabase.fileSizeString)) was not correctly saved, do you want to recover it?"
        //                let alert = UIAlertController(title: "Recovery", message: msg, preferredStyle: .alert)
        //                let alertActionNo = UIAlertAction(title: "Ignore", style: .destructive) {
        //                    (UIAlertAction) -> Void in
        //                    do {
        //                        try FileManager.default.removeItem(at: tmpDatabase)
        //                    }
        //                    catch {
        //                        print("Could not clear tmp database: \(error)")
        //                    }
        //                    self.newScan()
        //                }
        //                alert.addAction(alertActionNo)
        //                let alertActionCancel = UIAlertAction(title: "Cancel", style: .cancel) {
        //                    (UIAlertAction) -> Void in
        //                    // do nothing
        //                }
        //                alert.addAction(alertActionCancel)
        //                let alertActionYes = UIAlertAction(title: "Yes", style: .default) {
        //                    (UIAlertAction2) -> Void in
        //
        //                    let fileName = Date().getFormattedDate(format: "yyMMdd-HHmmss") + ".db"
        //                    let outputDbPath = self.getDocumentDirectory().appendingPathComponent(fileName).path
        //
        //                    var indicator: UIActivityIndicatorView?
        //
        //                    let alertView = UIAlertController(title: "Recovering", message: "Please wait while recovering data...", preferredStyle: .alert)
        //                    let alertViewActionCancel = UIAlertAction(title: "Cancel", style: .cancel) {
        //                        (UIAlertAction) -> Void in
        //                        self.dismiss(animated: true, completion: {
        //                            self.progressView = nil
        //
        //                            indicator = UIActivityIndicatorView(style: .large)
        //                            indicator?.frame = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
        //                            indicator?.center = self.view.center
        //                            self.view.addSubview(indicator!)
        //                            indicator?.bringSubviewToFront(self.view)
        //
        //                            indicator?.startAnimating()
        //                            self.rtabmap!.cancelProcessing();
        //                        })
        //                    }
        //                    alertView.addAction(alertViewActionCancel)
        //
        //                    let previousState = self.mState
        //                    self.updateState(state: .STATE_PROCESSING);
        //
        //                    self.present(alertView, animated: true, completion: {
        //                        //  Add your progressbar after alert is shown (and measured)
        //                        let margin:CGFloat = 8.0
        //                        let rect = CGRect(x: margin, y: 84.0, width: alertView.view.frame.width - margin * 2.0 , height: 2.0)
        //                        self.progressView = UIProgressView(frame: rect)
        //                        self.progressView!.progress = 0
        //                        self.progressView!.tintColor = self.view.tintColor
        //                        alertView.view.addSubview(self.progressView!)
        //
        //                        var success : Bool = false
        //                        DispatchQueue.background(background: {
        //
        //                            success = self.rtabmap!.recover(from: tmpDatabase.path, to: outputDbPath)
        //
        //                        }, completion:{
        //                            if(indicator != nil)
        //                            {
        //                                indicator!.stopAnimating()
        //                                indicator!.removeFromSuperview()
        //                            }
        //                            if self.progressView != nil
        //                            {
        //                                self.dismiss(animated: self.openedDatabasePath == nil, completion: {
        //                                    if(success)
        //                                    {
        //                                        let alertSaved = UIAlertController(title: "Database saved!", message: String(format: "Database \"%@\" successfully recovered!", fileName), preferredStyle: .alert)
        //                                        let yes = UIAlertAction(title: "OK", style: .default) {
        //                                            (UIAlertAction) -> Void in
        //                                            self.openDatabase(fileUrl: URL(fileURLWithPath: outputDbPath))
        //                                        }
        //                                        alertSaved.addAction(yes)
        //                                        self.present(alertSaved, animated: true, completion: nil)
        //                                    }
        //                                    else
        //                                    {
        //                                        self.updateState(state: previousState);
        //                                        self.showToast(message: "Recovery failed!", seconds: 4)
        //                                    }
        //                                })
        //                            }
        //                            else
        //                            {
        //                                self.showToast(message: "Recovery canceled", seconds: 2)
        //                                self.updateState(state: previousState);
        //                            }
        //                        })
        //                    })
        //                }
        //                alert.addAction(alertActionYes)
        //                self.present(alert, animated: true, completion: nil)
        //            })
        //        }
        //        else
        //        {
        self.rtabmap!.openDatabase(databasePath: "", databaseInMemory: true, optimize: false, clearDatabase: true)
        
        if(!(self.mState == State.STATE_CAMERA || self.mState == State.STATE_MAPPING))
        {
            self.setGLCamera(type: 0);
            self.startCamera();
        }
        //        }
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
    
    // MARK: UIView Functions
    
    private func setupButton(_ button: UIButton, title: String, iconName: String = "") {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        //        button.backgroundColor = color
        button.setImage(UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .medium, scale: .large)), for: .normal)
    }
    
    private func applyConstraints() {
        // Center Button Constraints
        NSLayoutConstraint.activate([
            centerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // StartRecord Button Constraints
        NSLayoutConstraint.activate([
            topRightButton.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 10),
            topRightButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // StopRecord Button Constraints
        NSLayoutConstraint.activate([
            bottomRightButton.topAnchor.constraint(equalTo: topRightButton.bottomAnchor, constant: 20),
            bottomRightButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // Bottom Center Button Constraints
        NSLayoutConstraint.activate([
            bottomCenterButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            bottomCenterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    
    // MARK: Override UIkit life cycle hook
    
    deinit {
        EAGLContext.setCurrent(context)
        rtabmap = nil
        context = nil
        EAGLContext.setCurrent(nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // The screen shouldn't dim during AR experiences.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
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
        
        // Setup buttons
        setupButton(centerButton, title: "Start the Camera", iconName: "camera.circle")
        setupButton(topRightButton, title: "", iconName: "record.circle")
        setupButton(bottomRightButton, title: "", iconName: "stop.circle")
        setupButton(bottomCenterButton, title: "Stop the Camera", iconName: "xmark.circle.fill")
        
        centerButton.tintColor = .white
        bottomCenterButton.tintColor = .white
        bottomRightButton.tintColor = .white
        
        topRightButton.tintColor = .systemRed
        
        // Add buttons to the view
        view.addSubview(centerButton)
        view.addSubview(topRightButton)
        view.addSubview(bottomRightButton)
        view.addSubview(bottomCenterButton)
        
        // Apply constraints
        applyConstraints()
        
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped(_:)))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
        
        
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateState(state: self.mState)
        }
    }
    
    // MARK: Update Status and etc
    
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
            actionNewScanEnabled = true
            actionSaveEnabled = false
            actionResumeEnabled = false
            actionExportEnabled = false
            actionOptimizeEnabled = false
            actionSettingsEnabled = false
        case .STATE_MAPPING:
            actionNewScanEnabled = true
            actionSaveEnabled = false
            actionResumeEnabled = false
            actionExportEnabled = false
            actionOptimizeEnabled = false
            actionSettingsEnabled = false
        case .STATE_PROCESSING,
                .STATE_VISUALIZING_WHILE_LOADING,
                .STATE_VISUALIZING_CAMERA:
            actionNewScanEnabled = false
            actionSaveEnabled = false
            actionResumeEnabled = false
            actionExportEnabled = false
            actionOptimizeEnabled = false
            actionSettingsEnabled = false
        case .STATE_VISUALIZING:
            actionNewScanEnabled = true
            actionSaveEnabled = mMapNodes>0
            actionResumeEnabled = mMapNodes>0
            actionExportEnabled = mMapNodes>0
            actionOptimizeEnabled = mMapNodes>0
            actionSettingsEnabled = true
        default: // IDLE // WELCOME
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
        
    }
    
    // MARK: Guestures
    
    var firstTouch: UITouch?
    var secondTouch: UITouch?
    
    override func touchesBegan(_ touches: Set<UITouch>,
                               with event: UIEvent?)
    {
        super.touchesBegan(touches, with: event)
        
        let touchList:Set<UITouch> = event?.allTouches ?? touches // fix a bug in swift ui
        
        for touch in touchList {
            if (firstTouch == nil) {
                firstTouch = touch
                let pose = touch.location(in: self.view)
                let normalizedX = pose.x / self.view.bounds.size.width;
                let normalizedY = pose.y / self.view.bounds.size.height;
                rtabmap?.onTouchEvent(touch_count: 1, event: 0, x0: Float(normalizedX), y0: Float(normalizedY), x1: 0.0, y1: 0.0);
            }
            else if (firstTouch != nil && secondTouch == nil)
            {
                secondTouch = touch
                if let pose0 = firstTouch?.location(in: self.view)
                {
                    if let pose1 = secondTouch?.location(in: self.view)
                    {
                        let normalizedX0 = pose0.x / self.view.bounds.size.width;
                        let normalizedY0 = pose0.y / self.view.bounds.size.height;
                        let normalizedX1 = pose1.x / self.view.bounds.size.width;
                        let normalizedY1 = pose1.y / self.view.bounds.size.height;
                        rtabmap?.onTouchEvent(touch_count: 2, event: 5, x0: Float(normalizedX0), y0: Float(normalizedY0), x1: Float(normalizedX1), y1: Float(normalizedY1));
                        
                        NSLog("\(normalizedX0)  --- \(normalizedY0) --- \(normalizedX1) --- \(normalizedY1)")
                    }
                }
            }
        }
        if self.isPaused {
            self.view.setNeedsDisplay()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        var firstTouchUsed = false
        var secondTouchUsed = false
        
        let touchList:Set<UITouch> = event?.allTouches ?? touches // fix a bug in swift ui
        
        for touch in touchList {
            if(touch == firstTouch)
            {
                firstTouchUsed = true
            }
            else if(touch == secondTouch)
            {
                secondTouchUsed = true
            }
        }
        if(secondTouch != nil)
        {
            if(firstTouchUsed || secondTouchUsed)
            {
                if let pose0 = firstTouch?.location(in: self.view)
                {
                    if let pose1 = secondTouch?.location(in: self.view)
                    {
                        let normalizedX0 = pose0.x / self.view.bounds.size.width;
                        let normalizedY0 = pose0.y / self.view.bounds.size.height;
                        let normalizedX1 = pose1.x / self.view.bounds.size.width;
                        let normalizedY1 = pose1.y / self.view.bounds.size.height;
                        rtabmap?.onTouchEvent(touch_count: 2, event: 2, x0: Float(normalizedX0), y0: Float(normalizedY0), x1: Float(normalizedX1), y1: Float(normalizedY1));
                    }
                }
            }
        }
        else if(firstTouchUsed)
        {
            if let pose = firstTouch?.location(in: self.view)
            {
                let normalizedX = pose.x / self.view.bounds.size.width;
                let normalizedY = pose.y / self.view.bounds.size.height;
                rtabmap?.onTouchEvent(touch_count: 1, event: 2, x0: Float(normalizedX), y0: Float(normalizedY), x1: 0.0, y1: 0.0);
            }
        }
        if self.isPaused {
            self.view.setNeedsDisplay()
        }
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        let touchList:Set<UITouch> = event?.allTouches ?? touches // fix a bug in swift ui
        
        for touch in touchList {
            if(touch == firstTouch)
            {
                firstTouch = nil
            }
            else if(touch == secondTouch)
            {
                secondTouch = nil
            }
        }
        if (firstTouch == nil && secondTouch != nil)
        {
            firstTouch = secondTouch
            secondTouch = nil
        }
        if (firstTouch != nil && secondTouch == nil)
        {
            let pose = firstTouch!.location(in: self.view)
            let normalizedX = pose.x / self.view.bounds.size.width;
            let normalizedY = pose.y / self.view.bounds.size.height;
            rtabmap?.onTouchEvent(touch_count: 1, event: 0, x0: Float(normalizedX), y0: Float(normalizedY), x1: 0.0, y1: 0.0);
        }
        if self.isPaused {
            self.view.setNeedsDisplay()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        let touchList:Set<UITouch> = event?.allTouches ?? touches // fix a bug in swift ui
        
        for touch in touchList {
            if(touch == firstTouch)
            {
                firstTouch = nil;
            }
            else if(touch == secondTouch)
            {
                secondTouch = nil;
            }
        }
        if self.isPaused {
            self.view.setNeedsDisplay()
        }
    }
    
    @IBAction func doubleTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizer.State.recognized
        {
            let pose = gestureRecognizer.location(in: gestureRecognizer.view)
            let normalizedX = pose.x / self.view.bounds.size.width;
            let normalizedY = pose.y / self.view.bounds.size.height;
            rtabmap?.onTouchEvent(touch_count: 3, event: 0, x0: Float(normalizedX), y0: Float(normalizedY), x1: 0.0, y1: 0.0);
            
            
            if self.isPaused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.view.setNeedsDisplay()
                }
            }
        }
    }
    
    @IBAction func singleTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizer.State.recognized
        {
            resetNoTouchTimer(!mHudVisible)
            
            if self.isPaused {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.view.setNeedsDisplay()
                }
            }
        }
    }
    
    
    // MARK: RTABMap Settings
    func updateDisplayFromDefaults()
    {
        //Get the defaults
        let defaults = UserDefaults.standard
        
        //let appendMode = defaults.bool(forKey: "AppendMode")
        
        // update preference
        rtabmap!.setOnlineBlending(enabled: defaults.bool(forKey: "Blending"));
        rtabmap!.setNodesFiltering(enabled: defaults.bool(forKey: "NodesFiltering"));
        rtabmap!.setFullResolution(enabled: defaults.bool(forKey: "HDMode"));
        rtabmap!.setSmoothing(enabled: defaults.bool(forKey: "Smoothing"));
        rtabmap!.setAppendMode(enabled: defaults.bool(forKey: "AppendMode"));
        
        mTimeThr = (defaults.string(forKey: "TimeLimit")! as NSString).integerValue
        mMaxFeatures = (defaults.string(forKey: "MaxFeaturesExtractedLoopClosure")! as NSString).integerValue
        
        // Mapping parameters
        rtabmap!.setMappingParameter(key: "Rtabmap/DetectionRate", value: defaults.string(forKey: "UpdateRate")!);
        rtabmap!.setMappingParameter(key: "Rtabmap/TimeThr", value: defaults.string(forKey: "TimeLimit")!);
        rtabmap!.setMappingParameter(key: "Rtabmap/MemoryThr", value: defaults.string(forKey: "MemoryLimit")!);
        rtabmap!.setMappingParameter(key: "RGBD/LinearSpeedUpdate", value: defaults.string(forKey: "MaximumMotionSpeed")!);
        let motionSpeed = ((defaults.string(forKey: "MaximumMotionSpeed")!) as NSString).floatValue/2.0;
        rtabmap!.setMappingParameter(key: "RGBD/AngularSpeedUpdate", value: NSString(format: "%.2f", motionSpeed) as String);
        rtabmap!.setMappingParameter(key: "Rtabmap/LoopThr", value: defaults.string(forKey: "LoopClosureThreshold")!);
        rtabmap!.setMappingParameter(key: "Mem/RehearsalSimilarity", value: defaults.string(forKey: "SimilarityThreshold")!);
        rtabmap!.setMappingParameter(key: "Kp/MaxFeatures", value: defaults.string(forKey: "MaxFeaturesExtractedVocabulary")!);
        rtabmap!.setMappingParameter(key: "Vis/MaxFeatures", value: defaults.string(forKey: "MaxFeaturesExtractedLoopClosure")!);
        rtabmap!.setMappingParameter(key: "Vis/MinInliers", value: defaults.string(forKey: "MinInliers")!);
        rtabmap!.setMappingParameter(key: "RGBD/OptimizeMaxError", value: defaults.string(forKey: "MaxOptimizationError")!);
        rtabmap!.setMappingParameter(key: "Kp/DetectorStrategy", value: defaults.string(forKey: "FeatureType")!);
        rtabmap!.setMappingParameter(key: "Vis/FeatureType", value: defaults.string(forKey: "FeatureType")!);
        rtabmap!.setMappingParameter(key: "Mem/NotLinkedNodesKept", value: defaults.bool(forKey: "SaveAllFramesInDatabase") ? "true" : "false");
        rtabmap!.setMappingParameter(key: "RGBD/OptimizeFromGraphEnd", value: defaults.bool(forKey: "OptimizationfromGraphEnd") ? "true" : "false");
        rtabmap!.setMappingParameter(key: "RGBD/MaxOdomCacheSize", value: defaults.string(forKey: "MaximumOdometryCacheSize")!);
        rtabmap!.setMappingParameter(key: "Optimizer/Strategy", value: defaults.string(forKey: "GraphOptimizer")!);
        rtabmap!.setMappingParameter(key: "RGBD/ProximityBySpace", value: defaults.string(forKey: "ProximityDetection")!);
        
        let markerDetection = defaults.integer(forKey: "ArUcoMarkerDetection")
        if(markerDetection == -1)
        {
            rtabmap!.setMappingParameter(key: "RGBD/MarkerDetection", value: "false");
        }
        else
        {
            rtabmap!.setMappingParameter(key: "RGBD/MarkerDetection", value: "true");
            rtabmap!.setMappingParameter(key: "Marker/Dictionary", value: defaults.string(forKey: "ArUcoMarkerDetection")!);
            rtabmap!.setMappingParameter(key: "Marker/CornerRefinementMethod", value: (markerDetection > 16 ? "3":"0"));
            rtabmap!.setMappingParameter(key: "Marker/MaxDepthError", value: defaults.string(forKey: "MarkerDepthErrorEstimation")!);
            if let val = NumberFormatter().number(from: defaults.string(forKey: "MarkerSize")!)?.doubleValue
            {
                rtabmap!.setMappingParameter(key: "Marker/Length", value: String(format: "%f", val/100.0))
            }
            else{
                rtabmap!.setMappingParameter(key: "Marker/Length", value: "0")
            }
        }
        
        // Rendering
        rtabmap!.setCloudDensityLevel(value: defaults.integer(forKey: "PointCloudDensity"));
        rtabmap!.setMaxCloudDepth(value: defaults.float(forKey: "MaxDepth"));
        rtabmap!.setMinCloudDepth(value: defaults.float(forKey: "MinDepth"));
        rtabmap!.setDepthConfidence(value: defaults.integer(forKey: "DepthConfidence"));
        rtabmap!.setPointSize(value: defaults.float(forKey: "PointSize"));
        rtabmap!.setMeshAngleTolerance(value: defaults.float(forKey: "MeshAngleTolerance"));
        rtabmap!.setMeshTriangleSize(value: defaults.integer(forKey: "MeshTriangleSize"));
        rtabmap!.setMeshDecimationFactor(value: defaults.float(forKey: "MeshDecimationFactor"));
        let bgColor = defaults.float(forKey: "BackgroundColor");
        rtabmap!.setBackgroundColor(gray: bgColor);
        
        //        DispatchQueue.main.async {
        //            self.statusLabel.textColor = bgColor>=0.6 ? UIColor(white: 0.0, alpha: 1) : UIColor(white: 1.0, alpha: 1)
        //        }
        
        rtabmap!.setClusterRatio(value: defaults.float(forKey: "NoiseFilteringRatio"));
        rtabmap!.setMaxGainRadius(value: defaults.float(forKey: "ColorCorrectionRadius"));
        rtabmap!.setRenderingTextureDecimation(value: defaults.integer(forKey: "TextureResolution"));
        
        if(locationManager != nil && !defaults.bool(forKey: "SaveGPS"))
        {
            locationManager?.stopUpdatingLocation()
            locationManager = nil
            mLastKnownLocation = nil
        }
        else if(locationManager == nil && defaults.bool(forKey: "SaveGPS"))
        {
            locationManager = CLLocationManager()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            locationManager?.delegate = self
        }
    }
    
    // MARK: RTABMap protocols
    
    func progressUpdated(_ rtabmap: RTABMap, count: Int, max: Int) {
        DispatchQueue.main.async {
            self.progressView?.setProgress(Float(count)/Float(max), animated: true)
        }
    }
    
    func initEventReceived(_ rtabmap: RTABMap, status: Int, msg: String) {
        DispatchQueue.main.async {
            var optimizedMeshDetected = 0
            
            if(msg == "Loading optimized cloud...done!")
            {
                optimizedMeshDetected = 1;
            }
            else if(msg == "Loading optimized mesh...done!")
            {
                optimizedMeshDetected = 2;
            }
            else if(msg == "Loading optimized texture mesh...done!")
            {
                optimizedMeshDetected = 3;
            }
            if(optimizedMeshDetected > 0)
            {
                if(optimizedMeshDetected==1)
                {
                    self.setMeshRendering(viewMode: 0)
                }
                else if(optimizedMeshDetected==2)
                {
                    self.setMeshRendering(viewMode: 1)
                }
                else // isOBJ
                {
                    self.setMeshRendering(viewMode: 2)
                }
                
                self.updateState(state: .STATE_VISUALIZING_WHILE_LOADING);
                self.setGLCamera(type: 2);
                
                self.dismiss(animated: true)
                self.showToast(message: "Optimized mesh detected in the database, it is shown while the database is loading...", seconds: 3)
            }
            
            let usedMem = self.getMemoryUsage()
            //            self.statusLabel.text =
            //                "Status: " + (status == 1 && msg.isEmpty ? self.mState == State.STATE_CAMERA ? "Camera Preview" : "Idle" : msg) + "\n" +
            //                "Memory Usage: \(usedMem) MB"
        }
    }
    
    func statsUpdated(_ rtabmap: RTABMap, nodes: Int, words: Int, points: Int, polygons: Int, updateTime: Float, loopClosureId: Int, highestHypId: Int, databaseMemoryUsed: Int, inliers: Int, matches: Int, featuresExtracted: Int, hypothesis: Float, nodesDrawn: Int, fps: Float, rejected: Int, rehearsalValue: Float, optimizationMaxError: Float, optimizationMaxErrorRatio: Float, distanceTravelled: Float, fastMovement: Int, landmarkDetected: Int, x: Float, y: Float, z: Float, roll: Float, pitch: Float, yaw: Float) {
        let usedMem = self.getMemoryUsage()
        
        if(loopClosureId > 0)
        {
            mTotalLoopClosures += 1;
        }
        let previousNodes = mMapNodes
        mMapNodes = nodes;
        
        //        let formattedDate = Date().getFormattedDate(format: "HH:mm:ss.SSS")
        
        DispatchQueue.main.async {
            
            if(self.mMapNodes>0 && previousNodes==0 && self.mState != .STATE_MAPPING)
            {
                self.updateState(state: self.mState) // refesh menus and actions
            }
            
            //            self.statusLabel.text = ""
            //            if self.statusShown {
            //                self.statusLabel.text =
            //                self.statusLabel.text! +
            //                "Status: \(self.getStateString(state: self.mState))\n" +
            //                "Memory Usage : \(usedMem) MB"
            //            }
            if self.debugShown {
                //                self.statusLabel.text =
                //                self.statusLabel.text! + "\n"
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
                
                //                self.statusLabel.text =
                //                self.statusLabel.text! +
                //                gpsString + //gps
                //                lightString + //env sensors
                ////                "Time: \(formattedDate)\n" +
                //                "Nodes (WM): \(nodes) (\(nodesDrawn) shown)\n" +
                //                "Words: \(words)\n" +
                //                "Database (MB): \(databaseMemoryUsed)\n" +
                //                "Number of points: \(points)\n" +
                //                "Polygons: \(polygons)\n" +
                //                "Update time (ms): \(Int(updateTime)) / \(self.mTimeThr==0 ? "No Limit" : String(self.mTimeThr))\n" +
                //                "Features: \(featuresExtracted) / \(self.mMaxFeatures==0 ? "No Limit" : (self.mMaxFeatures == -1 ? "Disabled" : String(self.mMaxFeatures)))\n" +
                //                "Rehearsal (%): \(Int(rehearsalValue*100))\n" +
                //                "Loop closures: \(self.mTotalLoopClosures)\n" +
                //                "Inliers: \(inliers)\n" +
                //                "Hypothesis (%): \(Int(hypothesis*100)) / \(Int(self.mLoopThr*100)) (\(loopClosureId>0 ? loopClosureId : highestHypId))\n" +
                //                String(format: "FPS (rendering): %.1f Hz\n", fps) +
                //                String(format: "Travelled distance: %.2f m\n", distanceTravelled) +
                //                String(format: "Pose (x,y,z): %.2f %.2f %.2f", x, y, z)
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
        //
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        //
        return 0
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        //
        return 0
    }
}

extension RGBDCaptureViewController: GLKViewControllerDelegate {
    
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

func clearBackgroundColor(of view: UIView) {
    if let effectsView = view as? UIVisualEffectView {
        effectsView.removeFromSuperview()
        return
    }
    
    view.backgroundColor = .clear
    view.subviews.forEach { (subview) in
        clearBackgroundColor(of: subview)
    }
}
