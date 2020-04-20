import AVFoundation
import UIKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var cameraView: UIView!

    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput?
    var prevLayer: AVCaptureVideoPreviewLayer?
    
    let sampleBufferQueue = DispatchQueue.global(qos: .background)
    var processing = false
    let cv = OpenCVWrapper()
    let detectionsCanvas = DetectionsCanvas()

    override func viewDidLoad() {
        super.viewDidLoad()
        detectionsCanvas.isOpaque = false
        view.addSubview(detectionsCanvas)
        detectionsCanvas.labelmap = loadLabels()
        verifyCameraPermissions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prevLayer?.frame.size = cameraView.frame.size
        detectionsCanvas.frame = cameraView.frame
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait]
    }
    
    func verifyCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                self.createSession()
            
            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.sync {
                            self.createSession()
                        }
                    }
                }
            
            case .denied: // The user has previously denied access.
                return

            case .restricted: // The user can't grant access due to restrictions.
                return

        @unknown default:
            return
        }

    }
    
    func createSession() {
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSession.Preset.photo
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        do {
            input = try AVCaptureDeviceInput(device: device!)
            guard input != nil else { return }
            session?.addInput(input!)
            
            prevLayer = AVCaptureVideoPreviewLayer(session: session!)
            prevLayer?.backgroundColor = UIColor.black.cgColor
            prevLayer?.frame.size = cameraView.frame.size
            prevLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
            
            cameraView.layer.addSublayer(prevLayer!)

            let output = AVCaptureVideoDataOutput()
            let bufferPixelFormatKey = (kCVPixelBufferPixelFormatTypeKey as NSString) as String
            
            output.videoSettings = [bufferPixelFormatKey: NSNumber(value: kCVPixelFormatType_32BGRA)]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            session?.addOutput(output)
            output.connection(with: AVMediaType.video)?.videoOrientation = .portrait // MUST be after session.addOutput
            
            session?.startRunning()

        } catch {
            print(error)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if (processing) {
            return
        }
        
        // On first frame save the frame witdth/height
        if (detectionsCanvas.capFrameWidth == 0) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
            
            CVPixelBufferLockBaseAddress( pixelBuffer, .readOnly )
            detectionsCanvas.capFrameWidth = CVPixelBufferGetWidth(pixelBuffer)
            detectionsCanvas.capFrameHeight = CVPixelBufferGetHeight(pixelBuffer)
            CVPixelBufferUnlockBaseAddress( pixelBuffer, .readOnly )
            return
        }

        processing = true

        let start = DispatchTime.now().uptimeNanoseconds
        let res = cv.detect(sampleBuffer)
        let span = DispatchTime.now().uptimeNanoseconds - start
        print("Detection time: \(span / 1000000) msec")

        // Convert results to Float and set it for drawing on the canvas
        detectionsCanvas.detections = res.compactMap {($0 as! Float)}

        DispatchQueue.main.async { [weak self] in
            self!.detectionsCanvas.setNeedsDisplay()
            self!.processing = false
        }
    }
    
    func loadLabels() -> [String] {
        var res = [String]()
        if let filepath = Bundle.main.path(forResource: "labelmap", ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                res = contents.split { $0.isNewline }.map(String.init)
            } catch {
                print("Error loading labelmap.txt file")
            }
        }
        
        return res
    }
}

// Used to draw detection rectangles on screen
class DetectionsCanvas: UIView {
    var labelmap = [String]()
    var detections = [Float]() // Raw results from detector

    // The size of the image we run detection on
    var capFrameWidth = 0
    var capFrameHeight = 0
    
    override func draw(_ rect: CGRect) {
        if (detections.count < 1) {return}
        if (detections.count % 6 > 0) {return;} // Each detection should have 6 numbers (classId, scrore, xmin, xmax, ymin, ymax)

        guard let context = UIGraphicsGetCurrentContext() else {return}
        context.clear(self.frame)

        // detection coords are in frame coord system, convert to screen coords
        let scaleX = self.frame.size.width / CGFloat(capFrameWidth)
        let scaleY = self.frame.size.height / CGFloat(capFrameHeight)

        // The camera view offset on screen
        let xoff = self.frame.minX
        let yoff = self.frame.minY
        
        let count = detections.count / 6
        for i in 0..<count {
            let idx = i * 6
            let classId = Int(detections[idx])
            let score = detections[idx + 1]
            if (score < 0.6) {continue}
            
            let xmin = xoff + CGFloat(detections[idx + 2]) * scaleX
            let xmax = xoff + CGFloat(detections[idx + 3]) * scaleX
            let ymin = yoff + CGFloat(detections[idx + 4]) * scaleY
            let ymax = yoff + CGFloat(detections[idx + 5]) * scaleY
            
            // SSD Mobilenet Model assumes class 0 is background class and detection result class
            // are zero-based (meaning class id 0 is class 1)
            let labelIdx = classId + 1
            let label = labelmap.count > labelIdx ? labelmap[labelIdx] : classId.description

            // Draw rect
            context.beginPath()
            context.move(to: CGPoint(x: xmin, y: ymin))
            context.addLine(to: CGPoint(x: xmax, y: ymin))
            context.addLine(to: CGPoint(x: xmax, y: ymax))
            context.addLine(to: CGPoint(x: xmin, y: ymax))
            context.addLine(to: CGPoint(x: xmin, y: ymin))

            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.red.cgColor)
            context.drawPath(using: .stroke)

            // Draw label
            UIGraphicsPushContext(context)
            let font = UIFont.systemFont(ofSize: 30)
            let string = NSAttributedString(string: label, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.red])
            string.draw(at: CGPoint(x: xmin, y: ymin))
        }
        
        UIGraphicsPopContext()
    }
}
