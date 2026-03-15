let vTuberStorageDirectory = "VTuber"

class VTuberStorage: FileStorage {
    init() {
        super.init(directory: vTuberStorageDirectory)
    }
}
