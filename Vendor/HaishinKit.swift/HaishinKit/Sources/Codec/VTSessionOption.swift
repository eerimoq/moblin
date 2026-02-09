import Foundation

/// A structure that represents  Key-Value-Object for the VideoToolbox option.
struct VTSessionOption {
    let key: VTSessionOptionKey
    let value: AnyObject
}

extension VTSessionOption: Hashable {
    // MARK: Hashable
    static func == (lhs: VTSessionOption, rhs: VTSessionOption) -> Bool {
        return lhs.key.CFString == rhs.key.CFString
    }

    func hash(into hasher: inout Hasher) {
        return hasher.combine(key.CFString)
    }
}
