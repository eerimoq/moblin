import Collections
import Foundation
import Network

class NetworkInterfaceTypeSelector {
    private let networkPathMonitor = NWPathMonitor()
    private var interfaceTypes: Deque<NWInterface.InterfaceType> = [.cellular, .wifi, .wiredEthernet, .other]

    init(queue: DispatchQueue) {
        networkPathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else {
                return
            }
            interfaceTypes.removeAll()
            if path.availableInterfaces.contains(where: { $0.type == .wifi }) {
                interfaceTypes.append(.wifi)
            }
            if path.availableInterfaces.contains(where: { $0.type == .cellular }) {
                interfaceTypes.append(.cellular)
            }
            if path.availableInterfaces.contains(where: { $0.type == .wiredEthernet }) {
                interfaceTypes.append(.wiredEthernet)
            }
            if path.availableInterfaces.contains(where: { $0.type == .other }) {
                interfaceTypes.append(.other)
            }
        }
        networkPathMonitor.start(queue: queue)
    }

    func getNextType() -> NWInterface.InterfaceType? {
        guard let interfaceType = interfaceTypes.popFirst() else {
            return nil
        }
        interfaceTypes.append(interfaceType)
        return interfaceType
    }
}
