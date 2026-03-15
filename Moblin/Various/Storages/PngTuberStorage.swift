let pngTuberStorageDirectory = "PNGTuber"

class PngTuberStorage: FileStorage {
    init() {
        super.init(directory: pngTuberStorageDirectory)
    }
}
