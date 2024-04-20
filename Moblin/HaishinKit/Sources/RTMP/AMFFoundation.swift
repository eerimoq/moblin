import Foundation

let kASUndefined = ASUndefined()

public typealias ASObject = [String: Any?]

struct ASUndefined: CustomStringConvertible {
    public var description: String {
        "undefined"
    }
}

struct ASTypedObject {
    typealias TypedObjectDecoder = () throws -> Any

    static var decoders: [String: TypedObjectDecoder] = [:]

    static func decode(typeName: String, data _: ASObject) throws -> Any {
        let decoder = decoders[typeName] ?? { ASTypedObject() }
        return try decoder()
    }
}

struct ASArray {
    private(set) var data: [Any?]
    private(set) var dict: [String: Any?] = [:]

    var length: Int {
        data.count
    }

    init(count: Int) {
        data = [Any?](repeating: kASUndefined, count: count)
    }

    init(data: [Any?]) {
        self.data = data
    }
}

extension ASArray: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Any?...) {
        self = ASArray(data: elements)
    }

    subscript(i: Any) -> Any? {
        get {
            if let i: Int = i as? Int {
                return i < data.count ? data[i] : kASUndefined
            }
            if let i: String = i as? String {
                if let i = Int(i) {
                    return i < data.count ? data[i] : kASUndefined
                }
                return dict[i] as Any
            }
            return nil
        }
        set {
            if let i: Int = i as? Int {
                if data.count <= i {
                    data += [Any?](repeating: kASUndefined, count: i - data.count + 1)
                }
                data[i] = newValue
            }
            if let i: String = i as? String {
                if let i = Int(i) {
                    if data.count <= i {
                        data += [Any?](repeating: kASUndefined, count: i - data.count + 1)
                    }
                    data[i] = newValue
                    return
                }
                dict[i] = newValue
            }
        }
    }
}

extension ASArray: CustomDebugStringConvertible {
    public var debugDescription: String {
        data.description
    }
}

extension ASArray: Equatable {
    public static func == (lhs: ASArray, rhs: ASArray) -> Bool {
        (lhs.data.description == rhs.data.description) && (lhs.dict.description == rhs.dict.description)
    }
}

// ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0
/// - seealso: 2.17 XML Document Type (amf0-file-format-specification.pdf)
/// - seealso: 3.9 XMLDocument type (amf-file-format-spec.pdf)
public struct ASXMLDocument: CustomStringConvertible {
    public var description: String {
        data
    }

    private let data: String

    /// Creates a new instance of string.
    public init(data: String) {
        self.data = data
    }
}

extension ASXMLDocument: Equatable {
    public static func == (lhs: ASXMLDocument, rhs: ASXMLDocument) -> Bool {
        lhs.description == rhs.description
    }
}

/// ActionScript 3.0 introduces a new XML type.
/// - seealso: 3.13 XML type (amf-file-format-spec.pdf)
public struct ASXML: CustomStringConvertible {
    public var description: String {
        data
    }

    private let data: String

    /// Creates a new instance of string.
    public init(data: String) {
        self.data = data
    }
}

extension ASXML: Equatable {
    public static func == (lhs: ASXML, rhs: ASXML) -> Bool {
        lhs.description == rhs.description
    }
}
