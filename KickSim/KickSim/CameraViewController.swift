import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var shapeLayer = CAShapeLayer()
    var bodyPoseRequest = VNDetectHumanBodyPoseRequest()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
    }

    private func setupOverlay() {
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(shapeLayer)
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            print("Failed to access camera")
            return
        }

        session.addInput(videoInput)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // ✅ Force portrait orientation
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds
        if let connection = previewLayer?.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if let layer = previewLayer {
            view.layer.insertSublayer(layer, at: 0)
        }

        session.startRunning()
    }

    // Delegate: process each frame
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([bodyPoseRequest])
            if let observations = bodyPoseRequest.results as? [VNHumanBodyPoseObservation],
               let body = observations.first {
                DispatchQueue.main.async {
                    self.drawStickFigure(from: body)
                }
            }
        } catch {
            print("Pose request failed: \(error)")
        }
    }

    // Draw stick figure with labels
    private func drawStickFigure(from body: VNHumanBodyPoseObservation) {
        guard let points = try? body.recognizedPoints(.all) else { return }

        let joints: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.neck, .root),
            (.root, .rightHip), (.root, .leftHip),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.neck, .nose),
            (.neck, .rightShoulder), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.neck, .leftShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist)
        ]

        let path = UIBezierPath()

        // Draw bones
        for (jointA, jointB) in joints {
            guard let pointA = points[jointA], pointA.confidence > 0.2,
                  let pointB = points[jointB], pointB.confidence > 0.2 else { continue }

            let cgPointA = VNImagePointForNormalizedPoint(CGPoint(x: pointA.x, y: 1 - pointA.y),
                                                          Int(view.frame.width),
                                                          Int(view.frame.height))
            let cgPointB = VNImagePointForNormalizedPoint(CGPoint(x: pointB.x, y: 1 - pointB.y),
                                                          Int(view.frame.width),
                                                          Int(view.frame.height))

            path.move(to: cgPointA)
            path.addLine(to: cgPointB)
        }

        // Remove old labels
        view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

        // Draw joints + labels
        for (joint, point) in points {
            guard point.confidence > 0.2 else { continue }

            let cgPoint = VNImagePointForNormalizedPoint(CGPoint(x: point.x, y: 1 - point.y),
                                                         Int(view.frame.width),
                                                         Int(view.frame.height))

            // Circle
            path.move(to: cgPoint)
            path.addArc(withCenter: cgPoint, radius: 4.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)

            // Label
            let label = UILabel(frame: CGRect(x: cgPoint.x + 5, y: cgPoint.y - 10, width: 60, height: 12))
            label.text = joint.rawValue.rawValue
            label.font = UIFont.systemFont(ofSize: 8)
            label.textColor = .red
            label.tag = 999
            view.addSubview(label)
        }

        shapeLayer.path = path.cgPath
    }
}
