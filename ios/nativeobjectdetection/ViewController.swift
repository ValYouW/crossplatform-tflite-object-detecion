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
    let canvas = Canvas()

    override func viewDidLoad() {
        super.viewDidLoad()
        canvas.isOpaque = false
        view.addSubview(canvas)
        verifyCameraPermissions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prevLayer?.frame.size = cameraView.frame.size
        canvas.frame = view.frame
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
            output.connection(with: AVMediaType.video)?.videoOrientation = .portrait
            session?.addOutput(output)
            
            session?.startRunning()

        } catch {
            print(error)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if (processing) {
            return
        }

        processing = true

        let start = DispatchTime.now().uptimeNanoseconds
        let res = cv.detect(sampleBuffer)
        let span = DispatchTime.now().uptimeNanoseconds - start
        print("Detection time: \(span / 1000000) msec")

        canvas.detections = res.compactMap {($0 as! Float)}

        DispatchQueue.main.async { [weak self] in
            self!.canvas.setNeedsDisplay()
            self!.processing = false
        }
    }
}

class Canvas: UIView {
    var detections = [Float]()
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {return}
        if (detections.count < 1) {return}
        context.clear(self.frame)

        if (detections.count % 6 > 0) {return;}

        let count = detections.count / 6
        for i in 0..<count {
            let idx = i * 6
            let label = detections[idx].description
            let score = detections[idx + 1]
            if (score < 0.6) {continue}
            
            let xmin = CGFloat(detections[idx + 2])
            let xmax = CGFloat(detections[idx + 3])
            let ymin = CGFloat(detections[idx + 4])
            let ymax = CGFloat(detections[idx + 5])
            
            context.beginPath()
            context.move(to: CGPoint(x: xmin, y: ymin))
            context.addLine(to: CGPoint(x: xmax, y: ymin))
            context.addLine(to: CGPoint(x: xmax, y: ymax))
            context.addLine(to: CGPoint(x: xmin, y: ymax))
            context.addLine(to: CGPoint(x: xmin, y: ymin))

            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.red.cgColor)
            context.drawPath(using: .stroke)

            UIGraphicsPushContext(context)
            let font = UIFont.systemFont(ofSize: 30)
            let string = NSAttributedString(string: label, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.red])
            string.draw(at: CGPoint(x: xmin, y: ymin))
        }
        
        UIGraphicsPopContext()
    }
}
