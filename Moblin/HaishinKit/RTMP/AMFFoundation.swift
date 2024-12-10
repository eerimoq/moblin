import Foundation

let kASUndefined = AsUndefined()

typealias AsObject = [String: Any?]

struct AsUndefined: CustomStringConvertible {
    var description: String {
        "undefined"
    }
}

struct ASTypedObject {
    typealias TypedObjectDecoder = () throws -> Any

    static var decoders: [String: TypedObjectDecoder] = [:]

    static func decode(typeName: String, data _: AsObject) throws -> Any {
        let decoder = decoders[typeName] ?? { ASTypedObject() }
        return try decoder()
    }
}

struct AsArray {
    private(set) var data: [Any?]
    private(set) var dict: [String: Any?] = [:]

    init(count: Int) {
        data = [Any?](repeating: kASUndefined, count: count)
    }

    init(data: [Any?]) {
        self.data = data
    }
}

extension AsArray: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: Any?...) {
        self = AsArray(data: elements)
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

extension AsArray: CustomDebugStringConvertible {
    public var debugDescription: String {
        data.description
    }
}

extension AsArray: Equatable {
    public static func == (lhs: AsArray, rhs: AsArray) -> Bool {
        (lhs.data.description == rhs.data.description) && (lhs.dict.description == rhs.dict.description)
    }
}

// ActionScript 1.0 and 2.0 and flash.xml.XMLDocument in ActionScript 3.0
/// - seealso: 2.17 XML Document Type (amf0-file-format-specification.pdf)
/// - seealso: 3.9 XMLDocument type (amf-file-format-spec.pdf)
public struct AsXmlDocument: CustomStringConvertible {
    public var description: String {
        data
    }

    private let data: String

    /// Creates a new instance of string.
    init(data: String) {
        self.data = data
    }
}

extension AsXmlDocument: Equatable {
    public static func == (lhs: AsXmlDocument, rhs: AsXmlDocument) -> Bool {
        lhs.description == rhs.description
    }
}

/// ActionScript 3.0 introduces a new XML type.
/// - seealso: 3.13 XML type (amf-file-format-spec.pdf)
public struct AsXml: CustomStringConvertible {
    public var description: String {
        data
    }

    private let data: String
}

extension AsXml: Equatable {
    public static func == (lhs: AsXml, rhs: AsXml) -> Bool {
        lhs.description == rhs.description
    }
}
