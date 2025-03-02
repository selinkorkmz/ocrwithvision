import UIKit
import Vision
import AVFoundation
import CoreImage
import Accelerate


class MRZOCRViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var overlayView: UIView!
    var instructionLabel: UILabel!
    var detectedMRZ: String = ""
    var detectionRect: CGRect!
    var isReadyToRead = false
    var stableFrameCount = 0
    let requiredStableFrames = 10  // Require 10 stable frames before reading MRZ
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
        setupInstructionLabel()
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
    
    func setupOverlay() {
        overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(overlayView)
        
        detectionRect = CGRect(x: view.bounds.midX - 150, y: view.bounds.midY - 100, width: 300, height: 200)
        let path = UIBezierPath(rect: view.bounds)
        let cutoutPath = UIBezierPath(roundedRect: detectionRect, cornerRadius: 10)
        path.append(cutoutPath.reversing())
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        overlayView.layer.mask = maskLayer
    }
    
    func setupInstructionLabel() {
        instructionLabel = UILabel(frame: CGRect(x: 20, y: detectionRect.maxY + 20, width: view.bounds.width - 40, height: 50))
        instructionLabel.text = "Please align your ID card within the frame and hold your phone steady."
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.boldSystemFont(ofSize: 18)
        instructionLabel.numberOfLines = 0
        view.addSubview(instructionLabel)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        recognizeText(from: pixelBuffer)
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
            
            if mrzLines.count == 3 && mrzLines.allSatisfy({ $0.count == 30 }) {
                self.stableFrameCount += 1
                if self.stableFrameCount >= self.requiredStableFrames {
                    DispatchQueue.main.async {
                        self.instructionLabel.text = "Scanning..."
                        self.captureSession.stopRunning()
                        self.processMRZ(mrzLines: mrzLines)
                    }
                }
            } else {
                self.stableFrameCount = 0
                DispatchQueue.main.async {
                    self.instructionLabel.text = "Please align your ID card within the frame and hold your phone steady."
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
        let surname = surnameComponents[0].replacingOccurrences(of: "<", with: "")
        let givenNames = surnameComponents[1...].joined(separator: " ").replacingOccurrences(of: "<", with: " ").replacingOccurrences(of: "<", with: "")
        
        showForm(surname: String(surname), givenNames: givenNames, idNumber: idNumber)
    }
    
    func showForm(surname: String, givenNames: String, idNumber: String) {
        let alert = UIAlertController(title: "MRZ Extracted", message: "Surname: \(surname)\nGiven Names: \(givenNames)\nID Number: \(idNumber)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.captureSession.startRunning()
            self.stableFrameCount = 0
            self.instructionLabel.text = "Please align your ID card within the frame and hold your phone steady."
        }))
        present(alert, animated: true)
    }
}
