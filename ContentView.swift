import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {

    @StateObject private var camera = CameraManager()

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Text("PS5 TÜRKÇE ÇEVİRİ")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Vision OCR")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(camera.recognizedText.isEmpty
                         ? "Altyazı bekleniyor..."
                         : camera.recognizedText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(.black.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding()
            }
        }
        .onAppear {
            camera.start()
        }
    }
}

final class CameraManager: NSObject, ObservableObject {

    let session = AVCaptureSession()

    @Published var recognizedText = ""

    private let videoOutput = AVCaptureVideoDataOutput()
    private let recognizer = CameraTextRecognizer()

    private var isProcessing = false

    func start() {

        switch AVCaptureDevice.authorizationStatus(for: .video) {

        case .authorized:
            configure()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.configure()
                    }
                }
            }

        default:
            DispatchQueue.main.async {
                self.recognizedText = "Kamera izni verilmedi."
            }
        }
    }

    private func configure() {

        guard !session.isRunning else {
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            session.commitConfiguration()
            return
        }

        do {

            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            videoOutput.setSampleBufferDelegate(
                self,
                queue: DispatchQueue(
                    label: "vision.camera.queue",
                    qos: .userInitiated
                )
            )

            videoOutput.alwaysDiscardsLateVideoFrames = true

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            if let connection = videoOutput.connection(
                with: .video
            ) {
                connection.videoOrientation = .portrait
            }

            session.commitConfiguration()

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }

        } catch {
            session.commitConfiguration()

            DispatchQueue.main.async {
                self.recognizedText = "Kamera başlatılamadı."
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {

        guard !isProcessing else {
            return
        }

        isProcessing = true

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        let context = CIContext()

        guard let cgImage = context.createCGImage(
            ciImage,
            from: ciImage.extent
        ) else {
            isProcessing = false
            return
        }

        let image = UIImage(
            cgImage: cgImage,
            scale: 1.0,
            orientation: .right
        )

        recognizer.recognizeText(from: image) { [weak self] texts in

            let filtered = texts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            DispatchQueue.main.async {
                if !filtered.isEmpty {
                    self?.recognizedText = filtered
                }

                self?.isProcessing = false
            }
        }
    }
}
