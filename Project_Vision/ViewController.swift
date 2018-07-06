//
//  ViewController.swift
//  Project_Vision
//
//  Created by iOS Development on 6/5/18.
//  Copyright © 2018 Smartivity. All rights reserved.
//

import AVFoundation
import UIKit
import Vision
import TesseractOCR


class ViewController: UIViewController , G8TesseractDelegate {
    private var textDetectionRequest: VNDetectTextRectanglesRequest?
    private let session = AVCaptureSession()
    private var textObservations = [VNTextObservation]()
    private var cameraView = CameraPreview()
    private var cameracontroller = CameraController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(cameraView)
        cameraView.frame = self.view.bounds

        if isAuthorized() {
            configureTextDetection()
            configureCamera()
        }
    }

    private func isAuthorized() -> Bool {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch authorizationStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted:Bool) -> Void in
                if granted {
                    DispatchQueue.main.async {
                        self.configureTextDetection()
                        self.configureCamera()
                    }
                }
            })
            return true
        case .authorized:
            return true
        case .denied, .restricted: return false
        }
    }

    private func configureTextDetection() {
        textDetectionRequest = VNDetectTextRectanglesRequest(completionHandler: handleDetection)
        textDetectionRequest?.reportCharacterBoxes = true
    }
    
  
    private func configureCamera() {
        cameraView.session = session
        
        let cameraDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        var cameraDevice: AVCaptureDevice?
        for device in cameraDevices.devices {
            if device.position == .back {
                cameraDevice = device
                break
            }
        }
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: cameraDevice!)
            if session.canAddInput(captureDeviceInput) {
                session.addInput(captureDeviceInput)
            }
        }
        catch {
            print("Error occured \(error)")
            return
        }
        session.sessionPreset = .high
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "project_vision_queue", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        cameraView.videoPreviewLayer.videoGravity = .resize
        session.startRunning()
    }
    
    private func handleDetection(request: VNRequest, error: Error?) {
        
        guard let detectionResults = request.results else {
            print("No detection results")
            return
        }
        let textResults = detectionResults.map() {
            return $0 as? VNTextObservation
        }
        if textResults.isEmpty {
            return
        }
        textObservations = textResults as! [VNTextObservation]
        print(textResults)
        DispatchQueue.main.async {
            
            guard let sublayers = self.view.layer.sublayers else {
                return
            }
            for layer in sublayers[1...] {
                if (layer as? CATextLayer) == nil {
                    layer.removeFromSuperlayer()
                }
            }
            let viewWidth = self.view.frame.size.width
            let viewHeight = self.view.frame.size.height
            for result in textResults {
                
                if let textResult = result {
                    
                    let layer = CALayer()
                    var rect = textResult.boundingBox
                    rect.origin.x *= viewWidth
                    rect.size.height *= viewHeight
                    rect.origin.y = ((1 - rect.origin.y) * viewHeight) - rect.size.height
                    rect.size.width *= viewWidth
                    
                    layer.frame = rect
                    layer.borderWidth = 2
                    layer.borderColor = UIColor.red.cgColor
                    self.view.layer.addSublayer(layer)
                }
            }
        }
    }

}






extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        var imageRequestOptions = [VNImageOption: Any]()
        if let cameraData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            imageRequestOptions[.cameraIntrinsics] = cameraData
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: imageRequestOptions)
     
        do {
            try imageRequestHandler.perform([textDetectionRequest!])
        }
        catch {
            print("Error occured \(error)")
        }
      
        if let tesseract = G8Tesseract(language: "eng") {
            tesseract.delegate = self
            self.processTextDetection(pixelBuffer: pixelBuffer, tesseract: tesseract)
            
            //  let _ = self.processRecognitionFromImage(image: UIImage(named: "textImg")!, tesseract: tesseract)
        }
        
    }

    
    func processRecognitionFromImage(image:UIImage, tesseract:G8Tesseract) -> String?{
        tesseract.image = image.g8_blackAndWhite()
        tesseract.recognize()
        let recognitisedText = tesseract.recognizedText
        print(recognitisedText as Any)
        return recognitisedText ?? nil
    }
    
    func processTextDetection(pixelBuffer:CVPixelBuffer, tesseract:G8Tesseract) {
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let transform = ciImage.orientationTransform(for: CGImagePropertyOrientation(rawValue: 6)!)
        ciImage = ciImage.transformed(by: transform)
        let size = ciImage.extent.size
      
        for textObservation in textObservations {
            guard let rects = textObservation.characterBoxes else {
                continue
            }
            var xMin = CGFloat.greatestFiniteMagnitude
            var xMax: CGFloat = 0
            var yMin = CGFloat.greatestFiniteMagnitude
            var yMax: CGFloat = 0
            for rect in rects {
                
                xMin = min(xMin, rect.bottomLeft.x)
                xMax = max(xMax, rect.bottomRight.x)
                yMin = min(yMin, rect.bottomRight.y)
                yMax = max(yMax, rect.topRight.y)
            }
            let imageRect = CGRect(x: xMin * size.width, y: yMin * size.height, width: (xMax - xMin) * size.width, height: (yMax - yMin) * size.height)
            let context = CIContext(options: nil)
            guard let cgImage = context.createCGImage(ciImage, from: imageRect) else {
                continue
            }
            let uiImage = UIImage(cgImage: cgImage)
            
            self.processRecognitionInRealTime(pixelBuffer: pixelBuffer, tesseract: tesseract, image: uiImage, xMin:xMin,xMax:xMax,yMin:yMin,yMax:yMax)

        }
       
    }
    
    func processRecognitionInRealTime(pixelBuffer:CVPixelBuffer, tesseract:G8Tesseract,image:UIImage, xMin:CGFloat,xMax:CGFloat,yMin:CGFloat,yMax:CGFloat ) {
        
            var recognizedTextPositionTuples = [(rect: CGRect, text: String)]()
            tesseract.image = image
            tesseract.recognize()
            var text = tesseract.recognizedText
             text = text?.trimmingCharacters(in: CharacterSet.newlines)
        if !(text?.isEmpty)! {
                let x = xMin
                let y = 1 - yMax
                let width = xMax - xMin
                let height = yMax - yMin
                recognizedTextPositionTuples.append((rect: CGRect(x: x, y: y, width: width, height: height), text: text!))
            }
        
        textObservations.removeAll()
        DispatchQueue.main.async {
            let viewWidth = self.view.frame.size.width
            let viewHeight = self.view.frame.size.height
            guard let sublayers = self.view.layer.sublayers else {
                return
            }
            for layer in sublayers[1...] {
                
                if let _ = layer as? CATextLayer {
                    layer.removeFromSuperlayer()
                }
            }
            for tuple in recognizedTextPositionTuples {
                let textLayer = CATextLayer()
                textLayer.backgroundColor = UIColor.clear.cgColor
                var rect = tuple.rect
                
                rect.origin.x *= viewWidth
                rect.size.width *= viewWidth
                rect.origin.y *= viewHeight
                rect.size.height *= viewHeight
                
                // Increase the size of text layer to show text of large lengths
                rect.size.width += 100
                rect.size.height += 100
                
                textLayer.frame = rect
                textLayer.string = tuple.text
                textLayer.foregroundColor = UIColor.green.cgColor
                self.view.layer.addSublayer(textLayer)
            }
        }
        
    }
    

}






















