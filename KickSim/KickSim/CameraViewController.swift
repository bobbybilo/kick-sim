import UIKit
import AVFoundation
import Vision
import AudioToolbox

import UIKit

class SpeedPlotView: UIView {
    var speeds: [(time: TimeInterval, speed: CGFloat)] = []

    override func draw(_ rect: CGRect) {
        guard speeds.count > 1 else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Clear the background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        // --- Padding for axes/labels ---
        let leftPadding: CGFloat = 60  // Increased for better label spacing
        let bottomPadding: CGFloat = 50  // Increased for better label spacing
        let plotRect = rect.inset(by: UIEdgeInsets(top: 20, left: leftPadding, bottom: bottomPadding, right: 20))

        // --- Scale values ---
        let maxSpeed = speeds.map { $0.speed }.max() ?? 1
        let minSpeed: CGFloat = 0
        let minTime = speeds.first!.time
        let maxTime = speeds.last!.time
        let timeRange = maxTime - minTime

        // --- Draw axes ---
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(2)

        // Y axis
        context.move(to: CGPoint(x: plotRect.minX, y: plotRect.minY))
        context.addLine(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))

        // X axis
        context.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        context.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))

        context.strokePath()

        // --- Draw ticks + labels ---
        let tickCount = 5

        // Y-axis (speed) ticks and labels
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1)
        
        for i in 0...tickCount {
            let fraction = CGFloat(i) / CGFloat(tickCount)
            let speedValue = minSpeed + fraction * (maxSpeed - minSpeed)
            let y = plotRect.maxY - fraction * plotRect.height

            // Draw tick mark
            context.move(to: CGPoint(x: plotRect.minX - 5, y: y))
            context.addLine(to: CGPoint(x: plotRect.minX, y: y))
            context.strokePath()

            // Draw label using Core Text
            let label = String(format: "%.0f", speedValue)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let attributedString = NSAttributedString(string: label, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: plotRect.minX - bounds.width - 10, y: y - bounds.height / 2)
            context.scaleBy(x: 1, y: -1)  // Flip text right-side up
            CTLineDraw(line, context)
            context.restoreGState()
        }

        // X-axis (time) ticks and labels
        for i in 0...tickCount {
            let fraction = CGFloat(i) / CGFloat(tickCount)
            let timeValue = minTime + Double(fraction) * timeRange
            let x = plotRect.minX + fraction * plotRect.width

            // Draw tick mark
            context.move(to: CGPoint(x: x, y: plotRect.maxY))
            context.addLine(to: CGPoint(x: x, y: plotRect.maxY + 5))
            context.strokePath()

            // Draw label using Core Text
            let label = String(format: "%.1fs", timeValue - minTime)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let attributedString = NSAttributedString(string: label, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString)
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: x - bounds.width / 2, y: plotRect.maxY + 15)
            context.scaleBy(x: 1, y: -1)  // Flip text right-side up
            CTLineDraw(line, context)
            context.restoreGState()
        }

        // Add axis titles
        // Y-axis title
        let yAxisTitle = "Speed (px/sec)"
        let yTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        let yAttributedTitle = NSAttributedString(string: yAxisTitle, attributes: yTitleAttributes)
        let yTitleLine = CTLineCreateWithAttributedString(yAttributedTitle)
        let yTitleBounds = CTLineGetBoundsWithOptions(yTitleLine, .useOpticalBounds)
        
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 15, y: plotRect.midY + yTitleBounds.width / 2)
        context.rotate(by: -CGFloat.pi / 2)  // Rotate 90 degrees
        context.scaleBy(x: 1, y: -1)
        CTLineDraw(yTitleLine, context)
        context.restoreGState()

        // X-axis title
        let xAxisTitle = "Time (seconds)"
        let xTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        let xAttributedTitle = NSAttributedString(string: xAxisTitle, attributes: xTitleAttributes)
        let xTitleLine = CTLineCreateWithAttributedString(xAttributedTitle)
        let xTitleBounds = CTLineGetBoundsWithOptions(xTitleLine, .useOpticalBounds)
        
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: plotRect.midX - xTitleBounds.width / 2, y: rect.maxY - 10)
        context.scaleBy(x: 1, y: -1)
        CTLineDraw(xTitleLine, context)
        context.restoreGState()

        // --- Draw line path ---
        guard timeRange > 0 && maxSpeed > minSpeed else { return }
        
        let path = UIBezierPath()
        for (i, entry) in speeds.enumerated() {
            let x = plotRect.minX + CGFloat((entry.time - minTime) / timeRange) * plotRect.width
            let y = plotRect.maxY - (entry.speed - minSpeed) / (maxSpeed - minSpeed) * plotRect.height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(3)
        context.addPath(path.cgPath)
        context.strokePath()
    }
}



// Main view controller handling camera input, Vision processing, and UI
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Properties

    var captureSession: AVCaptureSession?                     // Handles camera capture
    var previewLayer: AVCaptureVideoPreviewLayer?            // Displays live camera feed
    var shapeLayer = CAShapeLayer()                          // Used to draw stick figure overlay
    var bodyPoseRequest = VNDetectHumanBodyPoseRequest()     // Vision request for body pose

    private var isRecording = false                          // Whether app is currently recording motion
    private var lastTimestamp = Date()                       // Tracks last frame time (for FPS)
    private var anklePoints: [(time: TimeInterval, point: CGPoint)] = []  // Track right ankle points over time
    private var kicks: [(frame: Int, time: TimeInterval, speed: CGFloat)] = [] // Detected kicks
    private var recordingStartTime: TimeInterval?
    private var lastAnklePoint: (time: TimeInterval, point: CGPoint)?
    private var lastKickTime: TimeInterval?

    // UI Buttons
    private let startButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()     // Initialize camera and start session
        setupOverlay()    // Prepare the shape drawing layer
        setupButtons()    // Add start and stop buttons to the UI
    }
    
    // Calculate speed per frame (distance / Δt)
    private func calculateFrameSpeeds() -> [(time: TimeInterval, speed: CGFloat)] {
        var results: [(time: TimeInterval, speed: CGFloat)] = []
        guard anklePoints.count > 1 else { return results }

        for i in 1..<anklePoints.count {
            let current = anklePoints[i]
            let previous = anklePoints[i-1]
            let dt = current.time - previous.time
            guard dt > 0.0001 else { continue }

            let dx = current.point.x - previous.point.x
            let dy = current.point.y - previous.point.y
            let distance = sqrt(dx*dx + dy*dy)
            let speed = distance / CGFloat(dt)

            results.append((time: current.time, speed: speed))
        }
        return results
    }

    
    // MARK: - Kick Detection Logic

    private func computeLegSpeed() {
        guard anklePoints.count > 6 else { return }

        let trimmedPoints = Array(anklePoints.dropFirst(5))  // Skip early data points
        kicks.removeAll()  // Clear previous kicks

        let kickThreshold: CGFloat = 1000     // Minimum speed to count as a kick
        let cooldownSpeed: CGFloat = 400      // Speed to exit cooldown

        var isKicking = false
        var currentKickFrames: [(frame: Int, time: TimeInterval, speed: CGFloat)] = []

        for i in 1..<trimmedPoints.count {
            let current = trimmedPoints[i]
            guard let startTime = recordingStartTime, current.time - startTime > 0.2 else {
                continue  // Skip early data points within first 0.2 seconds
            }

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

            if speed > kickThreshold {
                currentKickFrames.append((frame: i, time: current.time, speed: speed))
                isKicking = true
            } else if speed < cooldownSpeed && isKicking {
                // Kick has ended — finalize it
                if let max = currentKickFrames.max(by: { $0.speed < $1.speed }) {
                    kicks.append(max)
                    print("🚀 Kick finalized at frame \(max.frame) — peak speed = \(Int(max.speed)) px/sec")
                }
                currentKickFrames.removeAll()
                isKicking = false
            }
        }

        // Edge case: kick ends at the last frame
        if isKicking, let max = currentKickFrames.max(by: { $0.speed < $1.speed }) {
            kicks.append(max)
            print("🚀 Kick finalized at frame \(max.frame) — peak speed = \(Int(max.speed)) px/sec")
        }

        // Summary after all frames
        print("✅ Total kicks: \(kicks.count)")
        if let top = kicks.max(by: { $0.speed < $1.speed }) {
            print("🏅 Peak kick: Frame \(top.frame), Speed = \(Int(top.speed)) px/sec")
        }

        // Show kick count on screen
        DispatchQueue.main.async {
            self.showKickCount()
        }
    }

    // MARK: - UI Display Functions

    // Show total number of kicks
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

        // Fade out after 2 seconds
        UIView.animate(withDuration: 0.5, delay: 2.0, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }

    // Draw green stick figure overlay on camera feed
    private func setupOverlay() {
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(shapeLayer)
    }

    // Show popup label for individual kick
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
        label.tag = 1234
        view.addSubview(label)

        // Fade out label after 1 second
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }

        // Access back-facing wide-angle camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            print("Failed to access camera")
            return
        }

        session.addInput(videoInput)

        // Set camera to 60 FPS if supported
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

        // Set up video output and delegate
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Force portrait mode
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        // Create and display preview layer
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

    // MARK: - Button Setup

    private func setupButtons() {
        // Start button styling
        startButton.setTitle("Start", for: .normal)
        startButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 8
        startButton.addTarget(self, action: #selector(startRecordingTapped), for: .touchUpInside)

        // Stop button styling
        stopButton.setTitle("Stop", for: .normal)
        stopButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.layer.cornerRadius = 8
        stopButton.addTarget(self, action: #selector(stopRecordingTapped), for: .touchUpInside)

        view.addSubview(startButton)
        view.addSubview(stopButton)

        // Button placement
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

    // MARK: - Recording Control

    @objc private func startRecordingTapped() {
        startRecording()
    }

    @objc private func stopRecordingTapped() {
        stopRecording()
    }

    func startRecording() {
        anklePoints.removeAll()
        isRecording = true
        recordingStartTime = Date().timeIntervalSince1970
        print("▶️ Recording started")
    }

    func stopRecording() {
        isRecording = false
        print("Frames captured: \(anklePoints.count)")
        computeLegSpeed()

        // Compute speed per frame and show plot
        let frameSpeeds = calculateFrameSpeeds()
        let plotVC = UIViewController()
        plotVC.view.backgroundColor = .white

        let plotView = SpeedPlotView(frame: plotVC.view.bounds)
        plotView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        plotView.speeds = frameSpeeds
        plotVC.view.addSubview(plotView)

        present(plotVC, animated: true, completion: nil)

        print("⏹️ Recording stopped")
    }


    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    // MARK: - Video Frame Processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard isRecording else { return }

        // Debug: Print FPS
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

                // Extract right ankle position
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
                    // Real-time kick detection
                    if let last = lastAnklePoint {
                        let dt = timestamp - last.time
                        guard dt > 0.001 else { return }

                        let dx = point.x - last.point.x
                        let dy = point.y - last.point.y
                        let distance = sqrt(dx * dx + dy * dy)
                        let speed = distance / CGFloat(dt)

                        let kickThreshold: CGFloat = 1000
                        let cooldownSpeed: CGFloat = 400
                        let cooldownTime: TimeInterval = 2

                        let now = Date().timeIntervalSince1970
                        let isInCooldown = (lastKickTime != nil) && (now - lastKickTime! < cooldownTime)

                        if speed > kickThreshold && !isInCooldown {
                            DispatchQueue.main.async {
                                self.showKickLabel(speed: speed)
                                AudioServicesPlaySystemSound(SystemSoundID(1057)) // 🔊 Beep now
                            }
                            lastKickTime = now
                        }
                    }

                    lastAnklePoint = (time: timestamp, point: point)

                }

                // Update overlay
                DispatchQueue.main.async {
                    self.drawStickFigure(from: body)
                }
            }
        } catch {
            print("Pose request failed: \(error)")
        }
    }
    
    func playBeep() {
        AudioServicesPlaySystemSound(1057) // System sound ID for a "short" beep
    }

    // MARK: - Drawing the Stick Figure Overlay
    

    private func drawStickFigure(from body: VNHumanBodyPoseObservation) {
        guard let points = try? body.recognizedPoints(.all) else { return }

        // Define joint connections for lines
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

        // Draw lines between joints
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

        // Remove old joint labels
        view.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }

        // Draw circles and labels at joints
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
