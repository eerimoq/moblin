import Foundation

class ImageStorage {
    private var fileManager: FileManager
    private var imagesUrl: URL
    
    init() {
        self.fileManager = FileManager.default
        let homeUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.imagesUrl = homeUrl.appendingPathComponent("Images")
        do {
            try fileManager.createDirectory(at: imagesUrl, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error("Error creating images directory: \(error)")
        }
    }
    
    func write(name: String, data: Data) {
        let path = imagesUrl.appendingPathComponent(name)
        do {
            try data.write(to: path)
        } catch {
            logger.error("images-storage: write failed with error \(error)")
        }
    }
    
    func read(name: String) -> Data? {
        do {
            let path = imagesUrl.appendingPathComponent(name)
            return try Data(contentsOf: path)
        } catch {
            logger.error("images-storage: read failed with error \(error)")
        }
        return nil
    }
}
