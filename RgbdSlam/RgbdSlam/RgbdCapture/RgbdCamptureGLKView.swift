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
import Zip

struct RGBDCaptureViewControllerWrapper: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> some GLKViewController {
        return RGBDCaptureViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Update the controller when your app's state changes, if necessary.
    }
}

class RGBDCaptureViewController: GLKViewController, ARSessionDelegate, RTABMapObserver {
    
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
    
    private let arView = ARSCNView()
//    private let session = ARSession()
    private var locationManager: CLLocationManager?
    private var mLastKnownLocation: CLLocation?
    private var mLastLightEstimate: CGFloat?
    
    private var context: EAGLContext?
    private var rtabmap: RTABMap?
    
    private var trackMaskView = GLKView()
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
    
    // MARK: UI Component
    
    // Button
    let newScanBtn = UIButton()
    let startRecordBtn = UIButton()
    let finishRecordBtn = UIButton()
    let stopCameraBtn = UIButton()
    
    // Label
    let statusLabel = UILabel()
    let toastLabel = UILabel()
    
    
    
    // MARK: Functions
    
    @objc func defaultsChanged(){
        updateDisplayFromDefaults()
    }
    
    func showToast(message : String, seconds: Double){
        if(!self.toastLabel.isHidden)
        {
            return;
        }
        NSLog("Toast Message --- [\(message)]")
        self.toastLabel.text = message
        self.toastLabel.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            self.toastLabel.isHidden = true
        }
    }
    
    @objc func appMovedToBackground() {
        if(mState == .STATE_VISUALIZING_CAMERA || mState == .STATE_MAPPING || mState == .STATE_CAMERA)
        {
            stopMapping(ignoreSaving: true)
        }
    }
    
    @objc func appMovedToForeground() {
        updateDisplayFromDefaults()
        
        if(mMapNodes > 0 && self.openedDatabasePath == nil)
        {
            let msg = "RTAB-Map has been pushed to background while mapping. Do you want to save the map now?"
            let alert = UIAlertController(title: "Mapping Stopped!", message: msg, preferredStyle: .alert)
            let alertActionNo = UIAlertAction(title: "Ignore", style: .cancel) {
                (UIAlertAction) -> Void in
            }
            alert.addAction(alertActionNo)
            let alertActionYes = UIAlertAction(title: "Yes", style: .default) {
                (UIAlertAction) -> Void in
                self.save()
            }
            alert.addAction(alertActionYes)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
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
                if let configuration = self.arView.session.configuration {
                    self.arView.session.run(configuration, options: [.resetSceneReconstruction, .resetTracking, .removeExistingAnchors])
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
    
    func startCamera()
    {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            print("Start Camera Function ...")
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
            
            self.arView.frame = self.view.bounds
            self.view.addSubview(arView)
            arView.session.run(configuration, options: [.resetSceneReconstruction, .resetTracking, .removeExistingAnchors])
            
            switch mState {
            case .STATE_VISUALIZING:
                updateState(state: .STATE_VISUALIZING_CAMERA)
            default:
                // locationManager?.startUpdatingLocation()
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
    
    func resumeScan()
    {
        if(mState == State.STATE_VISUALIZING)
        {
            closeVisualization()
            rtabmap!.postExportation(visualize: false)
        }
        
        let alertController = UIAlertController(title: "Append Mode", message: "The camera preview will not be aligned to map on start, move to a previously scanned area, then push Record. When a loop closure is detected, new scans will be appended to map.", preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
        }
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
        
        setGLCamera(type: 0);
        startCamera();
    }
    
    func newScan()
    {
        print("databases.size() = \(databases.size())")
        if(databases.count >= 5 && !mReviewRequested && self.depthSupported)
        {
            SKStoreReviewController.requestReviewInCurrentScene()
            mReviewRequested = true
        }
        
        if(mState == State.STATE_VISUALIZING)
        {
            closeVisualization()
        }
        
        mMapNodes = 0;
        self.openedDatabasePath = nil
        let tmpDatabase = self.getDocumentDirectory().appendingPathComponent(self.RTABMAP_TMP_DB)
        let inMemory = UserDefaults.standard.bool(forKey: "DatabaseInMemory")
        if(!(self.mState == State.STATE_CAMERA || self.mState == State.STATE_MAPPING) &&
           FileManager.default.fileExists(atPath: tmpDatabase.path) &&
           tmpDatabase.fileSize > 1024*1024) // > 1MB
        {
            dismiss(animated: true, completion: {
                let msg = "The previous session (\(tmpDatabase.fileSizeString)) was not correctly saved, do you want to recover it?"
                let alert = UIAlertController(title: "Recovery", message: msg, preferredStyle: .alert)
                let alertActionNo = UIAlertAction(title: "Ignore", style: .destructive) {
                    (UIAlertAction) -> Void in
                    do {
                        try FileManager.default.removeItem(at: tmpDatabase)
                    }
                    catch {
                        print("Could not clear tmp database: \(error)")
                    }
                    self.newScan()
                }
                alert.addAction(alertActionNo)
                let alertActionCancel = UIAlertAction(title: "Cancel", style: .cancel) {
                    (UIAlertAction) -> Void in
                    // do nothing
                }
                alert.addAction(alertActionCancel)
                let alertActionYes = UIAlertAction(title: "Yes", style: .default) {
                    (UIAlertAction2) -> Void in

                    let fileName = Date().getFormattedDate(format: "yyMMdd-HHmmss") + ".db"
                    let outputDbPath = self.getDocumentDirectory().appendingPathComponent(fileName).path
                    
                    var indicator: UIActivityIndicatorView?
                    
                    let alertView = UIAlertController(title: "Recovering", message: "Please wait while recovering data...", preferredStyle: .alert)
                    let alertViewActionCancel = UIAlertAction(title: "Cancel", style: .cancel) {
                        (UIAlertAction) -> Void in
                        self.dismiss(animated: true, completion: {
                            self.progressView = nil
                            
                            indicator = UIActivityIndicatorView(style: .large)
                            indicator?.frame = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
                            indicator?.center = self.view.center
                            self.view.addSubview(indicator!)
                            indicator?.bringSubviewToFront(self.view)
                            
                            indicator?.startAnimating()
                            self.rtabmap!.cancelProcessing();
                        })
                    }
                    alertView.addAction(alertViewActionCancel)
                    
                    let previousState = self.mState
                    self.updateState(state: .STATE_PROCESSING);
                    
                    self.present(alertView, animated: true, completion: {
                        //  Add your progressbar after alert is shown (and measured)
                        let margin:CGFloat = 8.0
                        let rect = CGRect(x: margin, y: 84.0, width: alertView.view.frame.width - margin * 2.0 , height: 2.0)
                        self.progressView = UIProgressView(frame: rect)
                        self.progressView!.progress = 0
                        self.progressView!.tintColor = self.view.tintColor
                        alertView.view.addSubview(self.progressView!)
                        
                        var success : Bool = false
                        DispatchQueue.background(background: {
                            
                            success = self.rtabmap!.recover(from: tmpDatabase.path, to: outputDbPath)
                            
                        }, completion:{
                            if(indicator != nil)
                            {
                                indicator!.stopAnimating()
                                indicator!.removeFromSuperview()
                            }
                            if self.progressView != nil
                            {
                                self.dismiss(animated: self.openedDatabasePath == nil, completion: {
                                    if(success)
                                    {
                                        let alertSaved = UIAlertController(title: "Database saved!", message: String(format: "Database \"%@\" successfully recovered!", fileName), preferredStyle: .alert)
                                        let yes = UIAlertAction(title: "OK", style: .default) {
                                            (UIAlertAction) -> Void in
                                            self.openDatabase(fileUrl: URL(fileURLWithPath: outputDbPath))
                                        }
                                        alertSaved.addAction(yes)
                                        self.present(alertSaved, animated: true, completion: nil)
                                    }
                                    else
                                    {
                                        self.updateState(state: previousState);
                                        self.showToast(message: "Recovery failed!", seconds: 4)
                                    }
                                })
                            }
                            else
                            {
                                self.showToast(message: "Recovery canceled", seconds: 2)
                                self.updateState(state: previousState);
                            }
                        })
                    })
                }
                alert.addAction(alertActionYes)
                self.present(alert, animated: true, completion: nil)
            })
        }
        else
        {
            self.rtabmap!.openDatabase(databasePath: tmpDatabase.path, databaseInMemory: inMemory, optimize: false, clearDatabase: true)

            if(!(self.mState == State.STATE_CAMERA || self.mState == State.STATE_MAPPING))
            {
                self.setGLCamera(type: 0);
                self.startCamera();
            }
        }
    }
    
    func save()
    {
        //Step : 1
        let alert = UIAlertController(title: "Save Scan", message: "RTAB-Map Database Name (*.db):", preferredStyle: .alert )
        //Step : 2
        let save = UIAlertAction(title: "Save", style: .default) { (alertAction) in
            let textField = alert.textFields![0] as UITextField
            if textField.text != "" {
                //Read TextFields text data
                let fileName = textField.text!+".db"
                let filePath = self.getDocumentDirectory().appendingPathComponent(fileName).path
                if FileManager.default.fileExists(atPath: filePath) {
                    let alert = UIAlertController(title: "File Already Exists", message: "Do you want to overwrite the existing file?", preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes", style: .default) {
                        (UIAlertAction) -> Void in
                        self.saveDatabase(fileName: fileName);
                    }
                    alert.addAction(yes)
                    let no = UIAlertAction(title: "No", style: .cancel) {
                        (UIAlertAction) -> Void in
                    }
                    alert.addAction(no)
                    
                    self.present(alert, animated: true, completion: nil)
                } else {
                    self.saveDatabase(fileName: fileName);
                }
            }
        }

        //Step : 3
        var placeholder = Date().getFormattedDate(format: "yyMMdd-HHmmss")
        if self.openedDatabasePath != nil && !self.openedDatabasePath!.path.isEmpty
        {
            var components = self.openedDatabasePath!.lastPathComponent.components(separatedBy: ".")
            if components.count > 1 { // If there is a file extension
                components.removeLast()
                placeholder = components.joined(separator: ".")
            } else {
                placeholder = self.openedDatabasePath!.lastPathComponent
            }
        }
        alert.addTextField { (textField) in
                textField.text = placeholder
        }

        //Step : 4
        alert.addAction(save)
        //Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in })

        self.present(alert, animated: true) {
            alert.textFields?.first?.selectAll(nil)
        }
    }
    
    func stopMapping(ignoreSaving: Bool)
    {
        arView.session.pause()
        arView.removeFromSuperview()
//        locationManager?.stopUpdatingLocation()
        rtabmap?.setPausedMapping(paused: true)
        rtabmap?.stopCamera()
        setGLCamera(type: 2)
        if(mState == .STATE_VISUALIZING_CAMERA)
        {
            self.rtabmap?.setLocalizationMode(enabled: false)
        }
        updateState(state: mState == .STATE_VISUALIZING_CAMERA ? .STATE_VISUALIZING : .STATE_IDLE);
        
        if !ignoreSaving
        {
            dismiss(animated: true, completion: {
                var msg = "Do you want to do standard graph optimization and make a nice assembled mesh now? This can be also done later using \"Optimize\" and \"Assemble\" menus."
                let depthUsed = self.depthSupported && UserDefaults.standard.bool(forKey: "LidarMode")
                if !depthUsed
                {
                    msg = "Do you want to do standard graph optimization now? This can be also done later using \"Optimize\" menu."
                }
                let alert = UIAlertController(title: "Mapping Stopped! Optimize Now?", message: msg, preferredStyle: .alert)
                if depthUsed {
                    let alertActionOnlyGraph = UIAlertAction(title: "Only Optimize", style: .default)
                    {
                        (UIAlertAction) -> Void in
                        self.optimization(withStandardMeshExport: false, approach: -1)
                    }
                    alert.addAction(alertActionOnlyGraph)
                }
                let alertActionNo = UIAlertAction(title: "Save First", style: .cancel) {
                    (UIAlertAction) -> Void in
                    self.save()
                }
                alert.addAction(alertActionNo)
                let alertActionYes = UIAlertAction(title: "Yes", style: .default) {
                    (UIAlertAction) -> Void in
                    self.optimization(withStandardMeshExport: depthUsed, approach: -1)
                }
                alert.addAction(alertActionYes)
                self.present(alert, animated: true, completion: nil)
            })
        }
        else if(mMapNodes == 0)
        {
            updateState(state: State.STATE_WELCOME);
            statusLabel.text = ""
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
            newScanBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newScanBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // StartRecord Button Constraints
        NSLayoutConstraint.activate([
            startRecordBtn.topAnchor.constraint(equalTo: view.centerYAnchor, constant: 10),
            startRecordBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // StopRecord Button Constraints
        NSLayoutConstraint.activate([
            finishRecordBtn.topAnchor.constraint(equalTo: startRecordBtn.bottomAnchor, constant: 20),
            finishRecordBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        // Bottom Center Button Constraints
        NSLayoutConstraint.activate([
            stopCameraBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            stopCameraBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Constraints for upper status label
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: stopCameraBtn.topAnchor, constant: -20)
        ])
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -350)
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
        
        self.toastLabel.isHidden = true
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
        
        arView.frame = self.view.bounds
        arView.session.delegate = self
        
        // Setup buttons
        setupButton(newScanBtn, title: "Start the Camera", iconName: "camera.circle")
        setupButton(startRecordBtn, title: "", iconName: "record.circle")
        setupButton(finishRecordBtn, title: "", iconName: "stop.circle")
        setupButton(stopCameraBtn, title: "Stop the Camera", iconName: "xmark.circle.fill")
        
        newScanBtn.tintColor = .white
        newScanBtn.addTarget(self, action: #selector(newScanAction), for: .touchUpInside)

        finishRecordBtn.tintColor = .white
        finishRecordBtn.addTarget(self, action: #selector(finishRecordAction), for: .touchUpInside)
        
        stopCameraBtn.tintColor = .white
        stopCameraBtn.addTarget(self, action: #selector(stopCameraAction), for: .touchUpInside)
        
        startRecordBtn.tintColor = .systemRed
        startRecordBtn.addTarget(self, action: #selector(startRecordAction), for: .touchUpInside)
        
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = .red
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        toastLabel.backgroundColor = .green
        toastLabel.textAlignment = .left
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add buttons to the view
        view.addSubview(newScanBtn)
        view.addSubview(startRecordBtn)
        view.addSubview(finishRecordBtn)
        view.addSubview(stopCameraBtn)
        
        // Add Label to the view
        view.addSubview(statusLabel)
        view.addSubview(toastLabel)
        
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
        
//        maxPolygonsPickerView = UIPickerView(frame: CGRect(x: 10, y: 50, width: 250, height: 150))
//        maxPolygonsPickerView.delegate = self
//        maxPolygonsPickerView.dataSource = self
        
        // This is where you can set your min/max values
        let minNum = 0
        let maxNum = 9
//        maxPolygonsPickerData = Array(stride(from: minNum, to: maxNum + 1, by: 1))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateState(state: self.mState)
        }
    }
    
    // Auto-hide the home indicator to maximize immersion in AR experiences.
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // Hide the status bar to maximize immersion in AR experiences.
    override var prefersStatusBarHidden: Bool {
        return !mHudVisible
    }
    
    override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
            // Make sure the button stays on top after layout changes
            view.bringSubviewToFront(startRecordBtn)
            view.bringSubviewToFront(finishRecordBtn)
            view.bringSubviewToFront(stopCameraBtn)
            view.bringSubviewToFront(statusLabel)
            view.bringSubviewToFront(toastLabel)
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
        
        var touchList:Set<UITouch>  = touches
        if event?.allTouches?.count == 2 {
            touchList = event?.allTouches ?? touches // fix a bug in swift ui
        }
        
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
        
        var touchList:Set<UITouch>  = touches
        if event?.allTouches?.count == 2 {
            touchList = event?.allTouches ?? touches // fix a bug in swift ui
        }
        
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
        
        var touchList:Set<UITouch>  = touches
        if event?.allTouches?.count == 2 {
            touchList = event?.allTouches ?? touches // fix a bug in swift ui
        }
        
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
        
        firstTouch = nil
        secondTouch = nil
        if self.isPaused {
            self.view.setNeedsDisplay()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        var touchList:Set<UITouch>  = touches
        if event?.allTouches?.count == 2 {
            touchList = event?.allTouches ?? touches // fix a bug in swift ui
        }
        
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
    
    // MARK: Export and DB
    
    func exportMesh(isOBJ: Bool)
    {
        let ac = UIAlertController(title: "Maximum Polygons", message: "\n\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        ac.view.addSubview(maxPolygonsPickerView)
        maxPolygonsPickerView.selectRow(2, inComponent: 0, animated: false)
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            let pickerValue = self.maxPolygonsPickerData[self.maxPolygonsPickerView.selectedRow(inComponent: 0)]
            self.export(isOBJ: isOBJ, meshing: true, regenerateCloud: false, optimized: true, optimizedMaxPolygons: pickerValue*100000, previousState: self.mState);
        }))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(ac, animated: true)
    }
    
    func shareFile(_ fileUrl: URL) {
        let fileURL = NSURL(fileURLWithPath: fileUrl.path)

        // Create the Array which includes the files you want to share
        var filesToShare = [Any]()

        // Add the path of the file to the Array
        filesToShare.append(fileURL)

        // Make the activityViewContoller which shows the share-view
        let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)
        
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popoverController.sourceView = self.view
            popoverController.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        }

        // Show the share-view
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    func openDatabase(fileUrl: URL) {
        
        if(mState == .STATE_CAMERA) {
            stopMapping(ignoreSaving: true)
        }
        
        openedDatabasePath = fileUrl;
        let fileName: String = self.openedDatabasePath!.lastPathComponent
        
        var progressDialog = UIAlertController(title: "Loading", message: String(format: "Loading \"%@\". Please wait while point clouds and/or meshes are created...", fileName), preferredStyle: .alert)
        
        //  Show it to your users
        self.present(progressDialog, animated: true)

        updateState(state: .STATE_PROCESSING);
        var status = 0
        DispatchQueue.background(background: {
            status = self.rtabmap!.openDatabase(databasePath: self.openedDatabasePath!.path, databaseInMemory: true, optimize: false, clearDatabase: false)
        }, completion:{
            // main thread
            if(status == -1) {
                self.dismiss(animated: true)
                self.showToast(message: "The map is loaded but optimization of the map's graph has failed, so the map cannot be shown. Change the Graph Optimizer approach used or enable/disable if the graph is optimized from graph end in \"Settings -> Mapping...\" and try opening again.", seconds: 4)
            }
            else if(status == -2) {
                self.dismiss(animated: true)
                self.showToast(message: "Failed to open database: Out of memory! Try again after lowering Point Cloud Density in Settings.", seconds: 4)
            }
            else {
                if(status >= 1 && status<=3) {
                    self.updateState(state: .STATE_VISUALIZING);
                    self.resetNoTouchTimer(true);
                }
                else {
                    self.setGLCamera(type: 2);
                    self.updateState(state: .STATE_IDLE);
                    self.dismiss(animated: true)
                    self.showToast(message: "Database loaded!", seconds: 2)
                }
            }
            
        })
    }
    
    func saveDatabase(fileName: String)
    {
        let filePath = self.getDocumentDirectory().appendingPathComponent(fileName).path
        
        let indicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .large)
        indicator.frame = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
        indicator.center = view.center
        view.addSubview(indicator)
        indicator.bringSubviewToFront(view)
        
        indicator.startAnimating()
        
        let previousState = mState;
        updateState(state: .STATE_PROCESSING);
        
        DispatchQueue.background(background: {
            self.rtabmap?.save(databasePath: filePath); // save
        }, completion:{
            // main thread
            indicator.stopAnimating()
            indicator.removeFromSuperview()
            
            self.openedDatabasePath = URL(fileURLWithPath: filePath)
            
            let alert = UIAlertController(title: "Database saved!", message: String(format: "Database \"%@\" successfully saved!", fileName), preferredStyle: .alert)
            let yes = UIAlertAction(title: "OK", style: .default) {
                (UIAlertAction) -> Void in
            }
            alert.addAction(yes)
            self.present(alert, animated: true, completion: nil)
            do {
                let tmpDatabase = self.getDocumentDirectory().appendingPathComponent(self.RTABMAP_TMP_DB)
                try FileManager.default.removeItem(at: tmpDatabase)
            }
            catch {
                print("Could not clear tmp database: \(error)")
            }
            self.updateDatabases()
            self.updateState(state: previousState)
        })
    }
    
    private func export(isOBJ: Bool, meshing: Bool, regenerateCloud: Bool, optimized: Bool, optimizedMaxPolygons: Int, previousState: State)
    {
        let defaults = UserDefaults.standard
        let cloudVoxelSize = defaults.float(forKey: "VoxelSize")
        let textureSize = isOBJ ? defaults.integer(forKey: "TextureSize") : 0
        let textureCount = defaults.integer(forKey: "MaximumOutputTextures")
        let normalK = defaults.integer(forKey: "NormalK")
        let maxTextureDistance = defaults.float(forKey: "MaxTextureDistance")
        let minTextureClusterSize = defaults.integer(forKey: "MinTextureClusterSize")
        let optimizedVoxelSize = cloudVoxelSize
        let optimizedDepth = defaults.integer(forKey: "ReconstructionDepth")
        let optimizedColorRadius = defaults.float(forKey: "ColorRadius")
        let optimizedCleanWhitePolygons = defaults.bool(forKey: "CleanMesh")
        let optimizedMinClusterSize = defaults.integer(forKey: "PolygonFiltering")
        let blockRendering = false
        
        var indicator: UIActivityIndicatorView?
        
        let alertView = UIAlertController(title: "Assembling", message: "Please wait while assembling data...", preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: {
                self.progressView = nil
                
                indicator = UIActivityIndicatorView(style: .large)
                indicator?.frame = CGRect(x: 0.0, y: 0.0, width: 60.0, height: 60.0)
                indicator?.center = self.view.center
                self.view.addSubview(indicator!)
                indicator?.bringSubviewToFront(self.view)
                
                indicator?.startAnimating()
                
                self.rtabmap!.cancelProcessing()
            })
            
        }))

        updateState(state: .STATE_PROCESSING);
        
        present(alertView, animated: true, completion: {
            //  Add your progressbar after alert is shown (and measured)
            let margin:CGFloat = 8.0
            let rect = CGRect(x: margin, y: 84.0, width: alertView.view.frame.width - margin * 2.0 , height: 2.0)
            self.progressView = UIProgressView(frame: rect)
            self.progressView!.progress = 0
            self.progressView!.tintColor = self.view.tintColor
            alertView.view.addSubview(self.progressView!)
            
            var success : Bool = false
            DispatchQueue.background(background: {
                
                success = self.rtabmap!.exportMesh(
                    cloudVoxelSize: cloudVoxelSize,
                    regenerateCloud: regenerateCloud,
                    meshing: meshing,
                    textureSize: textureSize,
                    textureCount: textureCount,
                    normalK: normalK,
                    optimized: optimized,
                    optimizedVoxelSize: optimizedVoxelSize,
                    optimizedDepth: optimizedDepth,
                    optimizedMaxPolygons: optimizedMaxPolygons,
                    optimizedColorRadius: optimizedColorRadius,
                    optimizedCleanWhitePolygons: optimizedCleanWhitePolygons,
                    optimizedMinClusterSize: optimizedMinClusterSize,
                    optimizedMaxTextureDistance: maxTextureDistance,
                    optimizedMinTextureClusterSize: minTextureClusterSize,
                    blockRendering: blockRendering)
                
            }, completion:{
                if(indicator != nil)
                {
                    indicator!.stopAnimating()
                    indicator!.removeFromSuperview()
                }
                if self.progressView != nil
                {
                    self.dismiss(animated: self.openedDatabasePath == nil, completion: {
                        if(success)
                        {
                            if(!meshing && cloudVoxelSize>0.0)
                            {
                                self.showToast(message: "Cloud assembled and voxelized at \(cloudVoxelSize) m.", seconds: 2)
                            }
                            
                            if(!meshing)
                            {
                                self.setMeshRendering(viewMode: 0)
                            }
                            else if(!isOBJ)
                            {
                                self.setMeshRendering(viewMode: 1)
                            }
                            else // isOBJ
                            {
                                self.setMeshRendering(viewMode: 2)
                            }

                            self.updateState(state: .STATE_VISUALIZING)
                            
                            self.rtabmap!.postExportation(visualize: true)

                            self.setGLCamera(type: 2)

                            if self.openedDatabasePath == nil
                            {
                                self.save();
                            }
                        }
                        else
                        {
                            self.updateState(state: previousState);
                            self.showToast(message: "Exporting map failed!", seconds: 4)
                        }
                    })
                }
                else
                {
                    self.showToast(message: "Export canceled", seconds: 2)
                    self.updateState(state: previousState);
                }
            })
        })
    }
    
    private func optimization(withStandardMeshExport: Bool = false, approach: Int)
    {
        if(mState == State.STATE_VISUALIZING)
        {
            closeVisualization()
            rtabmap!.postExportation(visualize: false)
        }
        
        let alertView = UIAlertController(title: "Post-Processing", message: "Please wait while optimizing...", preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.dismiss(animated: true)
            self.progressView = nil
            self.rtabmap!.cancelProcessing()
        }))

        let previousState = mState
        
        updateState(state: .STATE_PROCESSING)
        
        //  Show it to your users
        present(alertView, animated: true, completion: {
            //  Add your progressbar after alert is shown (and measured)
            let margin:CGFloat = 8.0
            let rect = CGRect(x: margin, y: 72.0, width: alertView.view.frame.width - margin * 2.0 , height: 2.0)
            self.progressView = UIProgressView(frame: rect)
            self.progressView!.progress = 0
            self.progressView!.tintColor = self.view.tintColor
            alertView.view.addSubview(self.progressView!)
            
            var loopDetected : Int = -1
            DispatchQueue.background(background: {
                loopDetected = self.rtabmap!.postProcessing(approach: approach);
            }, completion:{
                // main thread
                if self.progressView != nil
                {
                    self.dismiss(animated: self.openedDatabasePath == nil, completion: {
                        self.progressView = nil
                        
                        if(loopDetected >= 0)
                        {
                            if(approach  == -1)
                            {
                                if(withStandardMeshExport)
                                {
                                    self.export(isOBJ: true, meshing: true, regenerateCloud: false, optimized: true, optimizedMaxPolygons: 200000, previousState: previousState);
                                }
                                else
                                {
                                    if self.openedDatabasePath == nil
                                    {
                                        self.save();
                                    }
                                }
                            }
                        }
                        else if(loopDetected < 0)
                        {
                            self.showToast(message: "Optimization failed!", seconds: 4.0)
                        }
                    })
                }
                else
                {
                    self.showToast(message: "Optimization canceled", seconds: 4.0)
                }
                self.updateState(state: .STATE_IDLE);
            })
        })
    }
    
    func updateDatabases()
    {
        databases.removeAll()
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: getDocumentDirectory(), includingPropertiesForKeys: nil)
            // if you want to filter the directory contents you can do like this:
            
            let data = fileURLs.map { url in
                        (url, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
                    }
                    .sorted(by: { $0.1 > $1.1 }) // sort descending modification dates
                    .map { $0.0 } // extract file names
            databases = data.filter{ $0.pathExtension == "db" && $0.lastPathComponent != RTABMAP_TMP_DB && $0.lastPathComponent != RTABMAP_RECOVERY_DB }
            
        } catch {
            print("Error while enumerating files : \(error.localizedDescription)")
            return
        }
    }
    
    func rename(fileURL: URL)
    {
        //Step : 1
        let alert = UIAlertController(title: "Rename Scan", message: "RTAB-Map Database Name (*.db):", preferredStyle: .alert )
        //Step : 2
        let rename = UIAlertAction(title: "Rename", style: .default) { (alertAction) in
            let textField = alert.textFields![0] as UITextField
            if textField.text != "" {
                //Read TextFields text data
                let fileName = textField.text!+".db"
                let filePath = self.getDocumentDirectory().appendingPathComponent(fileName).path
                if FileManager.default.fileExists(atPath: filePath) {
                    let alert = UIAlertController(title: "File Already Exists", message: "Do you want to overwrite the existing file?", preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes", style: .default) {
                        (UIAlertAction) -> Void in
                        
                        do {
                            try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: filePath))
                            print("File \(fileURL) renamed to \(filePath)")
                        }
                        catch {
                            print("Error renaming file \(fileURL) to \(filePath)")
                        }
                        self.openLibrary()
                    }
                    alert.addAction(yes)
                    let no = UIAlertAction(title: "No", style: .cancel) {
                        (UIAlertAction) -> Void in
                    }
                    alert.addAction(no)
                    
                    self.present(alert, animated: true, completion: nil)
                } else {
                    do {
                        try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: filePath))
                        print("File \(fileURL) renamed to \(filePath)")
                    }
                    catch {
                        print("Error renaming file \(fileURL) to \(filePath)")
                    }
                    self.openLibrary()
                }
            }
        }

        //Step : 3
        alert.addTextField { (textField) in
            var components = fileURL.lastPathComponent.components(separatedBy: ".")
            if components.count > 1 { // If there is a file extension
              components.removeLast()
                textField.text = components.joined(separator: ".")
            } else {
                textField.text = fileURL.lastPathComponent
            }
        }

        //Step : 4
        alert.addAction(rename)
        //Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .default) { (alertAction) in })

        self.present(alert, animated: true) {
            alert.textFields?.first?.selectAll(nil)
        }
    }
    
    func exportOBJPLY()
    {
        //Step : 1
        let alert = UIAlertController(title: "Export Scan", message: "Model Name:", preferredStyle: .alert )
        //Step : 2
        let save = UIAlertAction(title: "Ok", style: .default) { (alertAction) in
            let textField = alert.textFields![0] as UITextField
            if textField.text != "" {
                self.dismiss(animated: true)
                //Read TextFields text data
                let fileName = textField.text!+".zip"
                let filePath = self.getDocumentDirectory().appendingPathComponent(fileName).path
                if FileManager.default.fileExists(atPath: filePath) {
                    let alert = UIAlertController(title: "File Already Exists", message: "Do you want to overwrite the existing file?", preferredStyle: .alert)
                    let yes = UIAlertAction(title: "Yes", style: .default) {
                        (UIAlertAction) -> Void in
                        self.writeExportedFiles(fileName: textField.text!);
                    }
                    alert.addAction(yes)
                    let no = UIAlertAction(title: "No", style: .cancel) {
                        (UIAlertAction) -> Void in
                    }
                    alert.addAction(no)
                    
                    self.present(alert, animated: true, completion: nil)
                } else {
                    self.writeExportedFiles(fileName: textField.text!);
                }
            }
        }

        //Step : 3
        alert.addTextField { (textField) in
            if self.openedDatabasePath != nil && !self.openedDatabasePath!.path.isEmpty
            {
                var components = self.openedDatabasePath!.lastPathComponent.components(separatedBy: ".")
                if components.count > 1 { // If there is a file extension
                    components.removeLast()
                    textField.text = components.joined(separator: ".")
                } else {
                    textField.text = self.openedDatabasePath!.lastPathComponent
                }
            }
            else {
                textField.text = Date().getFormattedDate(format: "yyMMdd-HHmmss")
            }
        }

        //Step : 4
        alert.addAction(save)
        //Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { (alertAction) in })

        self.present(alert, animated: true) {
            alert.textFields?.first?.selectAll(nil)
        }
    }

    func writeExportedFiles(fileName: String)
    {
        let alertView = UIAlertController(title: "Exporting", message: "Please wait while zipping data to \(fileName+".zip")...", preferredStyle: .alert)
        alertView.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.dismiss(animated: true)
            self.progressView = nil
            self.rtabmap!.cancelProcessing()
        }))
        
        let previousState = mState;

        updateState(state: .STATE_PROCESSING);
        
        present(alertView, animated: true, completion: {
            //  Add your progressbar after alert is shown (and measured)
            let margin:CGFloat = 8.0
            let rect = CGRect(x: margin, y: 84.0, width: alertView.view.frame.width - margin * 2.0 , height: 2.0)
            self.progressView = UIProgressView(frame: rect)
            self.progressView!.progress = 0
            self.progressView!.tintColor = self.view.tintColor
            alertView.view.addSubview(self.progressView!)
            
            let exportDir = self.getTmpDirectory().appendingPathComponent(self.RTABMAP_EXPORT_DIR)
           
            do {
                try FileManager.default.removeItem(at: exportDir)
            }
            catch
            {}
            
            do {
                try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
            }
            catch
            {
                print("Failed adding export directory \(exportDir)")
                return
            }
            
            var success : Bool = false
            var zipFileUrl : URL!
            DispatchQueue.background(background: {
                print("Exporting to directory \(exportDir.path) with name \(fileName)")
                if(self.rtabmap!.writeExportedMesh(directory: exportDir.path, name: fileName))
                {
                    do {
                        let fileURLs = try FileManager.default.contentsOfDirectory(at: exportDir, includingPropertiesForKeys: nil)
                        if(!fileURLs.isEmpty)
                        {
                            do {
                                zipFileUrl = try Zip.quickZipFiles(fileURLs, fileName: fileName) // Zip
                                print("Zip file \(zipFileUrl.path) created (size=\(zipFileUrl.fileSizeString)")
                                success = true
                            }
                            catch {
                              print("Something went wrong while zipping")
                            }
                        }
                    } catch {
                        print("No files exported to \(exportDir)")
                        return
                    }
                }
                
            }, completion:{
                if self.progressView != nil
                {
                    self.dismiss(animated: true)
                }
                if(success)
                {
                    let alertShare = UIAlertController(title: "Mesh/Cloud Saved!", message: "\(fileName+".zip") (\(zipFileUrl.fileSizeString) successfully exported in Documents of RTAB-Map! Share it?", preferredStyle: .alert)
                    let alertActionYes = UIAlertAction(title: "Yes", style: .default) {
                        (UIAlertAction) -> Void in
                        self.shareFile(zipFileUrl)
                    }
                    alertShare.addAction(alertActionYes)
                    let alertActionNo = UIAlertAction(title: "No", style: .cancel) {
                        (UIAlertAction) -> Void in
                       
                    }
                    alertShare.addAction(alertActionNo)
                    
                    self.present(alertShare, animated: true, completion: nil)
                }
                else
                {
                    self.showToast(message: "Exporting mesh/cloud canceled!", seconds: 2)
                }
                self.updateState(state: previousState);
            })
        })
    }
    
    func openLibrary()
    {
        updateDatabases();
        
        if databases.isEmpty {
            return
        }
        
        let alertController = UIAlertController(title: "Library", message: nil, preferredStyle: .alert)
//        let customView = VerticalScrollerView()
//        customView.dataSource = self
//        customView.delegate = self
//        customView.reload()
//        alertController.view.addSubview(customView)
//        customView.translatesAutoresizingMaskIntoConstraints = false
//        customView.topAnchor.constraint(equalTo: alertController.view.topAnchor, constant: 60).isActive = true
//        customView.rightAnchor.constraint(equalTo: alertController.view.rightAnchor, constant: -10).isActive = true
//        customView.leftAnchor.constraint(equalTo: alertController.view.leftAnchor, constant: 10).isActive = true
//        customView.bottomAnchor.constraint(equalTo: alertController.view.bottomAnchor, constant: -45).isActive = true
//        
        alertController.view.translatesAutoresizingMaskIntoConstraints = false
        alertController.view.heightAnchor.constraint(equalToConstant: 600).isActive = true
        alertController.view.widthAnchor.constraint(equalToConstant: 400).isActive = true
//
//        customView.backgroundColor = .darkGray

        let selectAction = UIAlertAction(title: "Select", style: .default) { (action) in
            self.openDatabase(fileUrl: self.databases[self.currentDatabaseIndex])
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(selectAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
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
        
        DispatchQueue.main.async {
              self.statusLabel.textColor = bgColor>=0.6 ? UIColor(white: 0.0, alpha: 1) : UIColor(white: 1.0, alpha: 1)
        }
        
        rtabmap!.setClusterRatio(value: defaults.float(forKey: "NoiseFilteringRatio"));
        rtabmap!.setMaxGainRadius(value: defaults.float(forKey: "ColorCorrectionRadius"));
        rtabmap!.setRenderingTextureDecimation(value: defaults.integer(forKey: "TextureResolution"));
        
//        if(locationManager != nil && !defaults.bool(forKey: "SaveGPS"))
//        {
//            locationManager?.stopUpdatingLocation()
//            locationManager = nil
//            mLastKnownLocation = nil
//        }
//        else if(locationManager == nil && defaults.bool(forKey: "SaveGPS"))
//        {
//            locationManager = CLLocationManager()
//            locationManager?.desiredAccuracy = kCLLocationAccuracyBestForNavigation
//            locationManager?.delegate = self
//        }
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
                        self.statusLabel.text =
                            "Status: " + (status == 1 && msg.isEmpty ? self.mState == State.STATE_CAMERA ? "Camera Preview" : "Idle" : msg) + "\n" +
                            "Memory Usage: \(usedMem) MB"
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
                //                "Time: \(formattedDate)\n" +
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
    
    // MARK: Link UIButton to Action
    
    @objc func newScanAction () {
        newScan()
    }
    
    @objc func stopCameraAction() {
        appMovedToBackground()
    }
    
    @objc func startRecordAction () {
        rtabmap?.setPausedMapping(paused: false);
        arView.alpha = 0.35
        updateState(state: .STATE_MAPPING)
    }
    
    @objc func finishRecordAction () {
        stopMapping(ignoreSaving: false)
    }
    
    @objc func closeVisualAction () {
        closeVisualization()
        rtabmap!.postExportation(visualize: false)
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
