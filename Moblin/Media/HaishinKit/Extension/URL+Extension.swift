import Foundation

extension URL {
    var absoluteWithoutAuthenticationString: String {
        guard var components = URLComponents(string: absoluteString) else {
            return absoluteString
        }
        components.password = nil
        components.user = nil
        return components.url?.absoluteString ?? absoluteString
    }

    func dictionaryFromQuery() -> [String: String] {
        var result: [String: String] = [:]
        guard let query = URLComponents(string: absoluteString)?.queryItems else {
            return result
        }
        for item in query {
            if let value: String = item.value {
                result[item.name] = value
            }
        }
        return result
    }
}
