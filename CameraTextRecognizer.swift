import Foundation
import Vision
import UIKit

final class CameraTextRecognizer {

    func recognizeText(
        from image: UIImage,
        completion: @escaping ([String]) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                completion([])
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []

            let texts = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            completion(texts)
        }

        // Kaliteyi önceliklendiriyoruz.
        request.recognitionLevel = .accurate

        // İngilizce altyazıya odaklan.
        request.recognitionLanguages = ["en-US"]

        // Apple'ın dil düzeltmesini kullan.
        request.usesLanguageCorrection = true

        // Çok küçük ekran yazılarını mümkün olduğunca ele.
        request.minimumTextHeight = 0.015

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: .right,
            options: [:]
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion([])
            }
        }
    }
}
