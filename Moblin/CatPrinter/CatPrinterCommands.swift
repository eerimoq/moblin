// Based on https://github.com/rbaron/catprinter
// MIT License

import Foundation

private let cmdGetDevState: [UInt8] = [
    81, 120, 163, 0, 1, 0, 0, 0, 255,
]
private let cmdSetQuality200Dpi: [UInt8] = [
    81, 120, 164, 0, 1, 0, 50, 158, 255,
]
private let cmdLatticeStart: [UInt8] = [
    81, 120, 166, 0, 11, 0, 170, 85, 23, 56, 68, 95, 95, 95, 68, 56, 44, 161, 255,
]
private let cmdLatticeEnd: [UInt8] = [
    81, 120, 166, 0, 11, 0, 170, 85, 23, 0, 0, 0, 0, 0, 0, 0, 23, 17, 255,
]
private let cmdSetPaper: [UInt8] = [
    81, 120, 161, 0, 2, 0, 48, 0, 249, 255,
]
private let checksumTable: [UInt8] = [
    0, 7, 14, 9, 28, 27, 18, 21, 56, 63, 54, 49, 36, 35, 42, 45, 112, 119, 126, 121,
    108, 107, 98, 101, 72, 79, 70, 65, 84, 83, 90, 93, 224, 231, 238, 233, 252, 251, 242, 245,
    216, 223, 214, 209, 196, 195, 202, 205, 144, 151, 158, 153, 140, 139, 130, 133, 168, 175, 166, 161,
    180, 179, 186, 189, 199, 192, 201, 206, 219, 220, 213, 210, 255, 248, 241, 246, 227, 228, 237, 234,
    183, 176, 185, 190, 171, 172, 165, 162, 143, 136, 129, 134, 147, 148, 157, 154, 39, 32, 41, 46,
    59, 60, 53, 50, 31, 24, 17, 22, 3, 4, 13, 10, 87, 80, 89, 94, 75, 76, 69, 66,
    111, 104, 97, 102, 115, 116, 125, 122, 137, 142, 135, 128, 149, 146, 155, 156, 177, 182, 191, 184,
    173, 170, 163, 164, 249, 254, 247, 240, 229, 226, 235, 236, 193, 198, 207, 200, 221, 218, 211, 212,
    105, 110, 103, 96, 117, 114, 123, 124, 81, 86, 95, 88, 77, 74, 67, 68, 25, 30, 23, 16,
    5, 2, 11, 12, 33, 38, 47, 40, 61, 58, 51, 52, 78, 73, 64, 71, 82, 85, 92, 91,
    118, 113, 120, 127, 106, 109, 100, 99, 62, 57, 48, 55, 34, 37, 44, 43, 6, 1, 8, 15,
    26, 29, 20, 19, 174, 169, 160, 167, 178, 181, 188, 187, 150, 145, 152, 159, 138, 141, 132, 131,
    222, 217, 208, 215, 194, 197, 204, 203, 230, 225, 232, 239, 250, 253, 244, 243,
]

private func calcCrc(_ b_arr: [UInt8], _ offset: Int, _ count: Int) -> UInt8 {
    var crc: UInt8 = 0
    for index in offset ..< offset + count {
        crc = checksumTable[Int((crc ^ b_arr[index]) & 0xFF)]
    }
    return crc
}

private func cmdFeedPaper(_ how_much: UInt8) -> [UInt8] {
    var b_arr: [UInt8] = [81, 120, 189, 0, 1, 0, how_much & 0xFF, 0, 0xFF]
    b_arr[7] = calcCrc(b_arr, 6, 1)
    return b_arr
}

private func encodeBit(_ img_row: [Bool], _ chunk_start: Int, _ bit_index: Int) -> UInt8 {
    if img_row[chunk_start + bit_index] {
        return 1 << bit_index
    } else {
        return 0
    }
}

private func encodeByte(_ img_row: [Bool]) -> [UInt8] {
    var res: [UInt8] = []
    for byte_start in 0 ..< img_row.count / 8 {
        var byte: UInt8 = 0
        for bit_index in 0 ..< 8 {
            byte |= encodeBit(img_row, byte_start * 8, bit_index)
        }
        res.append(byte)
    }
    return res
}

private func cmdPrintRow(_ img_row: [Bool]) -> [UInt8] {
    var encoded_img = encodeByte(img_row)
    var b_arr: [UInt8] = [81, 120, 162, 0, UInt8(encoded_img.count), 0]
    b_arr += encoded_img
    b_arr += [0, 0xFF]
    b_arr[-2] = calcCrc(b_arr, 6, encoded_img.count)
    return b_arr
}

func createPrintImageCommand(image: [[Bool]]) -> [UInt8] {
    var data = cmdGetDevState
    data += cmdSetQuality200Dpi
    data += cmdLatticeStart
    for row in image {
        data += cmdPrintRow(row)
    }
    data += cmdFeedPaper(25)
    data += cmdSetPaper
    data += cmdSetPaper
    data += cmdSetPaper
    data += cmdLatticeEnd
    data += cmdGetDevState
    return data
}
