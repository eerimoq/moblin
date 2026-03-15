import Foundation

let imagesStorageDirectory = "Images"

class ImageStorage: FileStorage {
    init() {
        super.init(directory: imagesStorageDirectory)
    }
}
