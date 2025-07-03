import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var shapeLayer = CAShapeLayer()
    var bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    

    private var isRecording = false
    private var lastTimestamp = Date()
    private var anklePoints: [(time: TimeInterval, point: CGPoint)] = []
    private var kicks: [(frame: Int, time: TimeInterval, speed: CGFloat)] = []


    // ✅ Buttons
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
        setupButtons()   // ✅ Add buttons on screen
    }
    
    // 1️⃣ Add storage:

    
    private func computeLegSpeed() {
        guard anklePoints.count > 6 else { return }

        let trimmedPoints = Array(anklePoints.dropFirst(5))
        kicks.removeAll()  // Clear previous session kicks

        var previousKickFrame = -10  // To avoid back-to-back detections
        let minFrameGap = 5          // Minimum frame gap between kicks

        let kickThreshold: CGFloat = 1000
        let cooldownSpeed: CGFloat = 400

        // Tracks whether we're allowed to detect a new kick
        var inCooldown = false

        for i in 1..<trimmedPoints.count {
            let current = trimmedPoints[i]
            let previous = trimmedPoints[i - 1]
            let dt = current.time - previous.time
            guard dt > 0.001 else { continue }

            let dx = current.point.x - previous.point.x
            let dy = current.point.y - previous.point.y
            let distance = sqrt(dx * dx + dy * dy)
            let speed = distance / CGFloat(dt)

            if speed > 10 {
                print("Frame \(i): speed = \(speed) px/sec")
            }

            if speed > kickThreshold && !inCooldown {
                kicks.append((frame: i, time: current.time, speed: speed))
                print("🚀 Kick detected at frame \(i) — speed = \(Int(speed)) px/sec")
                DispatchQueue.main.async {
                    self.showKickLabel(speed: speed)
                }
                inCooldown = true  // Start cooldown
            }

            if speed < cooldownSpeed {
                inCooldown = false  // Reset cooldown if motion has settled
            }
        }

        print("✅ Total kicks: \(kicks.count)")
        if let top = kicks.max(by: { $0.speed < $1.speed }) {
            print("🏅 Peak kick: Frame \(top.frame), Speed = \(Int(top.speed)) px/sec")
        }

        DispatchQueue.main.async {
            self.showKickCount()
        }
    }
    
    func showKickCount() {
        let label = UILabel()
        label.text = "Total Kicks: \(kicks.count)"
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.frame = CGRect(x: 40, y: 150, width: 200, height: 40)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        view.addSubview(label)

        UIView.animate(withDuration: 0.5, delay: 2.0, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }

    private func setupOverlay() {
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(shapeLayer)
    }
    
    func showKickLabel(speed: CGFloat) {
        let label = UILabel()
        label.text = "Kick! \(Int(speed)) px/sec"
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.frame = CGRect(x: 40, y: 100, width: 250, height: 40)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.alpha = 1
        label.tag = 1234  // Tag so we can remove it later if needed

        view.addSubview(label)

        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
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

        do {
            try videoDevice.lockForConfiguration()
            for format in videoDevice.formats {
                for range in format.videoSupportedFrameRateRanges {
                    if range.maxFrameRate >= 60 && range.minFrameRate <= 60 {
                        videoDevice.activeFormat = format
                        videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                        videoDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
                        print("Configured camera to use 60 FPS")
                        break
                    }
                }
            }
            videoDevice.unlockForConfiguration()
        } catch {
            print("Failed to set 60 FPS: \(error)")
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

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

    /// ✅ Setup UI buttons for start/stop
    private func setupButtons() {
        // Start button
        startButton.setTitle("Start", for: .normal)
        startButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 8
        startButton.addTarget(self, action: #selector(startRecordingTapped), for: .touchUpInside)

        // Stop button
        stopButton.setTitle("Stop", for: .normal)
        stopButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.layer.cornerRadius = 8
        stopButton.addTarget(self, action: #selector(stopRecordingTapped), for: .touchUpInside)

        // Place buttons on screen
        view.addSubview(startButton)
        view.addSubview(stopButton)

        // Auto-layout (bottom left & right)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.widthAnchor.constraint(equalToConstant: 80),
            startButton.heightAnchor.constraint(equalToConstant: 44),

            stopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stopButton.widthAnchor.constraint(equalToConstant: 80),
            stopButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // ✅ Buttons call these
    @objc private func startRecordingTapped() {
        startRecording()
    }

    @objc private func stopRecordingTapped() {
        stopRecording()
    }

    func startRecording() {
        anklePoints.removeAll() // 👈 very important
        isRecording = true
        print("▶️ Recording started")
    }


    func stopRecording() {
        isRecording = false
        print("Frames captured: \(anklePoints.count)")
        computeLegSpeed()
        print("⏹️ Recording stopped")
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // ✅ Only run Vision & log FPS if recording
        guard isRecording else { return }

        // ✅ FPS debug log — runs only if recording is true
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTimestamp)
        lastTimestamp = now
        let fps = Int(1.0 / elapsed)
        print("FPS: \(fps)")

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([bodyPoseRequest])

            if let observations = bodyPoseRequest.results as? [VNHumanBodyPoseObservation],
               let body = observations.first {

                // ✅ NEW: extract right ankle position and store it
                if let points = try? body.recognizedPoints(.all),
                   let ankle = points[.rightAnkle],
                   ankle.confidence > 0.5 {

                    let point = VNImagePointForNormalizedPoint(
                        CGPoint(x: ankle.x, y: 1 - ankle.y),
                        Int(view.frame.width),
                        Int(view.frame.height)
                    )
                    let timestamp = Date().timeIntervalSince1970
                    anklePoints.append((time: timestamp, point: point))
                }

                // ✅ Existing: update overlay
                DispatchQueue.main.async {
                    self.drawStickFigure(from: body)
                }
            }
        } catch {
            print("Pose request failed: \(error)")
        }
    }



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

        view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

        for (joint, point) in points {
            guard point.confidence > 0.2 else { continue }

            let cgPoint = VNImagePointForNormalizedPoint(CGPoint(x: point.x, y: 1 - point.y),
                                                         Int(view.frame.width),
                                                         Int(view.frame.height))

            path.move(to: cgPoint)
            path.addArc(withCenter: cgPoint, radius: 4.0, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)

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
