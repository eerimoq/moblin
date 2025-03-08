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

    func add(prompt _: String, url _: URL?) {
        guard #available(iOS 18.4, *) else {
            return
        }
        // Task {
        //     do {
        //         let creator = try await ImageCreator()
        //         var concepts = [.extracted(from: prompt)]
        //         if let url {
        //             concepts.append(.image(url))
        //         }
        //         for try await image in creator.images(for: concepts, style: .all, limit: 1) {
        //             self.delegate?.faxReceiverPrint(image: image)
        //         }
        //     } catch is ImageCreator.Error {
        //     } catch {
        //     }
        // }
    }
}
