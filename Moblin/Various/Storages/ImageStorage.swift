import Foundation

let imagesStorageDirectory = "Images"

class ImageStorage: FileStorage, @unchecked Sendable {
    init() {
        super.init(directory: imagesStorageDirectory)
    }
}
