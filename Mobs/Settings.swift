import SwiftUI

struct Database: Codable {
    var title: String = ""
    var lengthInMinutes: Int = 0
}

class Settings: ObservableObject {
    @Published var database = Database()
    @AppStorage("settings") var storage = ""

    func load() {
        do {
            self.database = try JSONDecoder().decode(Database.self, from: storage.data(using: .utf8)!)
        } catch {
            print("Failed to load settings.")
        }
    }

    func save(database: Database) throws {
        self.storage = String(decoding: try JSONEncoder().encode(database), as: UTF8.self)
    }
}
