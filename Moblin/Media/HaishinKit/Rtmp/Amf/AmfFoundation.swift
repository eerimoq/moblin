import Foundation

let kASUndefined = AsUndefined()

typealias AsObject = [String: Any?]

struct AsUndefined: CustomStringConvertible {
    var description: String {
        "undefined"
    }
}

struct AsTypedObject {
    static func decode(typeName _: String, data _: AsObject) throws -> Any {
        return AsTypedObject()
    }
}

struct AsArray {
    private(set) var items: [String: Any?] = [:]

    mutating func set(key: String, value: Any?) {
        items[key] = value
    }

    func get(key: String) throws -> Any? {
        guard let value = items[key] else {
            throw "Not found"
        }
        return value
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
