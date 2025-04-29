import UIKit

class AirPrinter {
    private var printerUrl: URL?

    init(printerUrl: URL?) {
        self.printerUrl = printerUrl
    }

    func selectPrinter() {
        let printerPicker = UIPrinterPickerController(initiallySelectedPrinter: nil)
        printerPicker.present(animated: true) { controller, userDidSelect, error in
            if userDidSelect, let selectedPrinter = controller.selectedPrinter {
                self.printerUrl = selectedPrinter.url
            } else if let error {
                logger.info("air-printer: Error: \(error.localizedDescription)")
            } else {
                self.printerUrl = nil
            }
        }
    }

    func print(image: UIImage) {
        guard let printerUrl else {
            return
        }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .photo
        printInfo.jobName = "Moblin"
        printController.printInfo = printInfo
        printController.printingItem = image
        let printer = UIPrinter(url: printerUrl)
        printController.print(to: printer, completionHandler: { _, completed, error in
            if completed {
            } else if let error {
                logger.info("air-printer: Failed to complete print job: \(error.localizedDescription)")
            } else {
                logger.info("air-printer: Print job was canceled.")
            }
        })
    }
}
