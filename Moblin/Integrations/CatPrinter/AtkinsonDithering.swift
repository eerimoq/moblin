import Foundation

class AtkinsonDithering {
    private var image: [[UInt8]] = []
    private var width: Int = 0
    private var height: Int = 0

    func apply(image: [[UInt8]]) -> [[UInt8]] {
        guard !image.isEmpty else {
            return image
        }
        self.image = image
        height = image.count
        width = image[0].count
        for y in 0 ..< height {
            for x in 0 ..< width {
                let newColor = self.image[y][x] > 127 ? 255 : 0
                let diff = Int(self.image[y][x]) - newColor
                self.image[y][x] = UInt8(newColor)
                adjustPixel(y: y, x: x + 1, delta: diff / 8)
                adjustPixel(y: y, x: x + 2, delta: diff / 8)
                adjustPixel(y: y + 1, x: x - 1, delta: diff / 8)
                adjustPixel(y: y + 1, x: x, delta: diff / 8)
                adjustPixel(y: y + 1, x: x + 1, delta: diff / 8)
                adjustPixel(y: y + 2, x: x, delta: diff / 8)
            }
        }
        return self.image
    }

    private func adjustPixel(y: Int, x: Int, delta: Int) {
        guard y >= 0, y < height, x >= 0, x < width else {
            return
        }
        image[y][x] = UInt8(min(255, max(0, Int(image[y][x]) + delta)))
    }
}
