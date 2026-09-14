import CoreImage
import Foundation
import ImagePlayground

@MainActor
protocol FaxReceiverDelegate: AnyObject {
    func faxReceiverPrint(image: CIImage)
}

@MainActor
class FaxReceiver {
    weak var delegate: (any FaxReceiverDelegate)?

    func add(url: URL) {
        httpRequest(request: URLRequest(url: url)) { data, response, _ in
            guard let data, response?.http?.isSuccessful == true else {
                return
            }
            guard let image = CIImage(data: data) else {
                return
            }
            self.delegate?.faxReceiverPrint(image: image)
        }
    }
}
