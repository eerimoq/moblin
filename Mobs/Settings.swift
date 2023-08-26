import SwiftUI

struct Database: Codable {
    var title: String = ""
    var lengthInMinutes: Int = 0
}

class Settings: ObservableObject {
    @Published var database: Database? = nil

    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
        .appendingPathComponent("settings.data")

    }
    
    func load() async throws {
        let task = Task<Database?, Error> {
            let fileURL = try Self.fileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            return try JSONDecoder().decode(Database.self, from: data)
        }
        self.database = try await task.value
    }

    func save(database: Database) async throws {
        let task = Task {
            let data = try JSONEncoder().encode(database)
            let fileURL = try Self.fileURL()
            try data.write(to: fileURL)
        }
        _ = try await task.value
    }
}
