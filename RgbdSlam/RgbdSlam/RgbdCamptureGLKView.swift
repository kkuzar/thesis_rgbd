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

struct GLKViewControllerWrapper: UIViewControllerRepresentable {
//    func makeUIViewController(context: Context) -> some GLKViewController {
//        return MyGLKViewController()
//    }
    
    func makeUIViewController(context: Context) -> some GLKViewController {
        return MyComplexViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Update the controller when your app's state changes, if necessary.
    }
}

class MyGLKViewController: GLKViewController {
    var glkView: GLKView!
    var effect: GLKBaseEffect!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        glkView = view as? GLKView
        glkView.context = EAGLContext(api: .openGLES3)!
        EAGLContext.setCurrent(glkView.context)
        
        setupGLContext()
        setupEffect()
    }
    
    private func setupGLContext() {
        let aspect = Float(view.bounds.size.width / view.bounds.size.height)
        let projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0), aspect, 0.1, 10.0)
        
        effect = GLKBaseEffect()
        effect.transform.projectionMatrix = projectionMatrix
    }
    
    private func setupEffect() {
        let modelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, -2.0)
        effect.transform.modelviewMatrix = modelViewMatrix
    }
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        glClearColor(0.1, 0.1, 0.2, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        effect.prepareToDraw()
        
        var vertices: [GLfloat] = [
            0.0,  1.0, 0.0,  // Vertex 1
            -1.0, -1.0, 0.0,  // Vertex 2
            1.0, -1.0, 0.0   // Vertex 3
        ]
        
        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
        glVertexAttribPointer(
            GLuint(GLKVertexAttrib.position.rawValue),
            3,
            GLenum(GL_FLOAT),
            GLboolean(GL_FALSE),
            0,
            &vertices
        )
        
        glDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        glDisableVertexAttribArray(GLuint(GLKVertexAttrib.position.rawValue))
    }
}

class MyComplexViewController: GLKViewController, ARSessionDelegate, RTABMapObserver, UIPickerViewDataSource, UIPickerViewDelegate, CLLocationManagerDelegate {
    func progressUpdated(_ rtabmap: RTABMap, count: Int, max: Int) {
        //
    }
    
    func initEventReceived(_ rtabmap: RTABMap, status: Int, msg: String) {
        //
    }
    
    func statsUpdated(_ rtabmap: RTABMap, nodes: Int, words: Int, points: Int, polygons: Int, updateTime: Float, loopClosureId: Int, highestHypId: Int, databaseMemoryUsed: Int, inliers: Int, matches: Int, featuresExtracted: Int, hypothesis: Float, nodesDrawn: Int, fps: Float, rejected: Int, rehearsalValue: Float, optimizationMaxError: Float, optimizationMaxErrorRatio: Float, distanceTravelled: Float, fastMovement: Int, landmarkDetected: Int, x: Float, y: Float, z: Float, roll: Float, pitch: Float, yaw: Float) {
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

