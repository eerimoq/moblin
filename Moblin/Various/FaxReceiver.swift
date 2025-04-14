import CoreImage
import Foundation
import ImagePlayground

protocol FaxReceiverDelegate: AnyObject {
    func faxReceiverPrint(image: CIImage)
}

class FaxReceiver {
    weak var delegate: (any FaxReceiverDelegate)?

    func add(url: URL) {
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, _ in
            guard let data, response?.http?.isSuccessful == true else {
                return
            }
            guard let image = CIImage(data: data) else {
                return
            }
            self.delegate?.faxReceiverPrint(image: image)
        }
        .resume()
    }

    func add(prompt: String, url: URL?) {
        guard #available(iOS 18.4, *) else {
            return
        }
        Task {
            do {
                let creator = try await ImageCreator()
                var concepts: [ImagePlaygroundConcept] = [.extracted(from: prompt, title: nil)]
                if let url, let image = ImagePlaygroundConcept.image(url) {
                    concepts.append(image)
                }
                for try await image in creator.images(for: concepts, style: .animation, limit: 1) {
                    self.delegate?.faxReceiverPrint(image: CIImage(cgImage: image.cgImage))
                }
            } catch {
                logger.info("fax-receiver: Error: \(error.localizedDescription)")
            }
        }
    }
}
