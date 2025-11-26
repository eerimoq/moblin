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
}
