import UIKit
import Vision
import AVFoundation
import CoreImage
import Accelerate

class MRZOCRViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var detectedMRZ: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if (captureSession.canAddOutput(videoOutput)) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        if let processedBuffer = preprocessImage(pixelBuffer) {
            recognizeText(from: processedBuffer)
        }
    }
    
    func preprocessImage(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let context = CIContext()
        let grayscale = CIFilter(name: "CIColorControls")
        grayscale?.setValue(ciImage, forKey: kCIInputImageKey)
        grayscale?.setValue(0.0, forKey: kCIInputSaturationKey)
        grayscale?.setValue(1.2, forKey: kCIInputContrastKey)
        
        guard let outputImage = grayscale?.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        let ciContext = CIContext(options: nil)
        var newPixelBuffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        
        CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height, kCVPixelFormatType_32BGRA, attributes, &newPixelBuffer)
        
        if let newPixelBuffer = newPixelBuffer {
            ciContext.render(CIImage(cgImage: cgImage), to: newPixelBuffer)
            return newPixelBuffer
        }
        
        return nil
    }
    
    func recognizeText(from pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            var mrzLines: [String] = []
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                
                if topCandidate.string.contains("<<<") {
                    mrzLines.append(topCandidate.string)
                }
            }
            
            if mrzLines.count >= 3 {
                DispatchQueue.main.async {
                    self.captureSession.stopRunning()
                    self.processMRZ(mrzLines: mrzLines)
                }
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try requestHandler.perform([request])
        } catch {
            print("OCR error: \(error.localizedDescription)")
        }
    }
    
    func processMRZ(mrzLines: [String]) {
        let idNumber = String(mrzLines[0].dropLast(3).suffix(11))
        let surnameComponents = mrzLines[2].split(separator: "<", omittingEmptySubsequences: false)
        let surname = surnameComponents[0]
        let givenNames = surnameComponents[1...].joined(separator: " ").replacingOccurrences(of: "<", with: " ")
        
        showForm(surname: String(surname), givenNames: givenNames, idNumber: idNumber)
    }
    
    func showForm(surname: String, givenNames: String, idNumber: String) {
        let alert = UIAlertController(title: "MRZ Extracted", message: "Surname: \(surname)\nGiven Names: \(givenNames)\nID Number: \(idNumber)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.captureSession.startRunning()
        }))
        present(alert, animated: true)
    }
}
