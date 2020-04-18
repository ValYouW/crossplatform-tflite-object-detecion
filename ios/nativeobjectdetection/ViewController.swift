import AVFoundation
import UIKit



class ViewController: UIViewController {

    @IBOutlet weak var cameraView: UIView!

    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput?
    var prevLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        verifyCameraPermissions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prevLayer?.frame.size = cameraView.frame.size
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
        device = AVCaptureDevice.default(for: AVMediaType.video)
        
        do{
            input = try AVCaptureDeviceInput(device: device!)
        }
        catch{
            print(error)
        }
        
        if let input = input{
            session?.addInput(input)
        }
        
        prevLayer = AVCaptureVideoPreviewLayer(session: session!)
        prevLayer?.frame.size = cameraView.frame.size
        prevLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        prevLayer?.connection?.videoOrientation = transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.rawValue ?? UIInterfaceOrientation.portrait.rawValue)!)
        
        cameraView.layer.addSublayer(prevLayer!)
        
        session?.startRunning()
    }

    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInTelephotoCamera, .builtInTrueDepthCamera, .builtInWideAngleCamera, ], mediaType: .video, position: position)
        
        if let device = deviceDiscoverySession.devices.first {
            return device
        }
        return nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) -> Void in
            self.prevLayer?.connection?.videoOrientation = self.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.windows.first?.windowScene?.interfaceOrientation.rawValue ?? UIInterfaceOrientation.portrait.rawValue)!)
            self.prevLayer?.frame.size = self.cameraView.frame.size
        }, completion: { (context) -> Void in
            
        })
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    func transformOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }

    

}

