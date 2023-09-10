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
            logger.error("image-storage: Error creating images directory: \(error)")
        }
    }
    
    func write(id: UUID, data: Data) {
        let path = imagesUrl.appendingPathComponent(id.uuidString)
        do {
            try data.write(to: path)
        } catch {
            logger.error("image-storage: write failed with error \(error)")
        }
    }
    
    func read(id: UUID) -> Data? {
        do {
            let path = imagesUrl.appendingPathComponent(id.uuidString)
            return try Data(contentsOf: path)
        } catch {
            logger.error("image-storage: read failed with error \(error)")
        }
        return nil
    }
}
