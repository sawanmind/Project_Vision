//
//  CameraPreview.swift
//  Project_Vision
//
//  Created by iOS Development on 6/5/18.
//  Copyright © 2018 Smartivity. All rights reserved.
//

import UIKit
import AVFoundation
class CameraPreview: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    var session: AVCaptureSession? {
        get {
            videoPreviewLayer.connection?.videoOrientation = .landscapeRight
           
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    // MARK: UIView
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

