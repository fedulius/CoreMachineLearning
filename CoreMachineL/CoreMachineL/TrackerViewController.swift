import UIKit
import AVFoundation
import Vision

class TrackerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var launchButton: UIButton!
    
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private lazy var prewiewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private var drawings: [CAShapeLayer] = []
    private var frame: CGRect = CGRect(x: 0, y: 0, width: 20, height: 20)
    private var resultsInController: [VNFaceObservation] = []
    var face: Bool = false
    var boom = UIImageView(image: UIImage(named: "boom"))
    var rocket = UIImageView(image: UIImage(named: "rocket"))

    override func viewDidLoad() {
        super.viewDidLoad()
        
        launchButton.isHidden = true
        self.addCameraInput()
        self.showCameraFeed()
        self.getCameraFrames()
        self.captureSession.startRunning()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        boom.image = UIImage(named: "boom")
        let boomSize = CGSize(width: boom.image!.size.width / 5, height: boom.image!.size.height / 5)
        boom.frame = CGRect(origin: CGPoint.zero, size: boomSize)
        boom.center = CGPoint(x: frame.origin.x + frame.size.width / 2, y: frame.origin.y + frame.size.height / 2 - 50)
    }
    
    @IBAction func startButton(_ sender: Any) {
        face = !face
        boom.layoutSubviews()
    }
    
    // MARK: - Camera
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.prewiewLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height - 150)
    }
    
    private func getCameraFrames() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video), connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    private func showCameraFeed() {
        self.prewiewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.prewiewLayer)
        self.prewiewLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height - 150)
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .front).devices.first else {
            fatalError("No back camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    //MARK: - face detected request
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { (request, err) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation], results.count > 0 {
                    self.resultsInController = results
                    self.launchButton.isHidden = false
                    self.handleFaceDetectionResults(results)
                    let current = self.prewiewLayer.layerRectConverted(fromMetadataOutputRect: results[0].boundingBox)
                    self.boom.frame = current
                    self.rocket.frame = current
                    if self.face == true {
                        self.drawAndAnimate(current)
                    }
                    self.boom.layoutSubviews()
                } else {
                    self.launchButton.isHidden = true
                    self.clearDrawings()
                }
            }
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    //MARK: - Rsults of Face detector(rectangle)
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        self.clearDrawings()
        let faceBoundingBoxes: [CAShapeLayer] = observedFaces.map { (observedFace: VNFaceObservation) -> CAShapeLayer in
            let faceBoundingBoxOnScreen = self.prewiewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            frame = faceBoundingBoxPath.boundingBox
            let faceBoundingBoxShape = CAShapeLayer()
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.yellow.cgColor
            return faceBoundingBoxShape
        }
        
        faceBoundingBoxes.forEach { (faceBoundeingBox) in
            self.view.layer.addSublayer(faceBoundeingBox)
        }
        
        self.drawings = faceBoundingBoxes
    }
    
    private func clearDrawings() {
        self.drawings.forEach { (drawing) in
            drawing.removeFromSuperlayer()
        }
    }
    
    //MARK: - Draw rocket and animate
    private func drawAndAnimate(_ current: CGRect) {
        let rocketSize = CGSize(width: rocket.image!.size.width / 5, height: rocket.image!.size.height / 5)
        rocket.frame = CGRect(origin: CGPoint.zero, size: rocketSize)
        rocket.center = CGPoint(x: view.frame.size.width / 2, y: view.frame.size.height - rocket.image!.size.height / 7 - 20)
        rocket.alpha = 1
        boom.center = CGPoint(x: self.frame.origin.x + self.frame.size.width / 2, y: self.frame.origin.y + self.frame.size.height / 2 - 50)
        boom.alpha = 0
        boom.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        view.addSubview(rocket)
        view.addSubview(boom)
        
        let distance = view.frame.size.width / min(self.frame.size.width, self.frame.size.height)
        let duration = Double(distance) * 0.45
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn], animations: {
            self.rocket.center = self.boom.center
        }) { (_) in
            self.rocket.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseOut, animations: {
                self.boom.alpha = 1
                self.boom.transform = CGAffineTransform(scaleX: 1, y: 1)
            }) { (_) in
                UIView.animate(withDuration: 0.7, delay: 0, options: .curveEaseOut, animations: {
                    self.boom.alpha = 0
                    self.boom.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }) { (_) in
                    
                }
            }
        }
        face = false
    }
    
    //MARK: - Buffer Delegete
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("unable to get image")
            return
        }
        self.detectFace(in: frame)
        DispatchQueue.main.async {
            self.boom.layoutSubviews()
        }
    }
    
    
    
}

