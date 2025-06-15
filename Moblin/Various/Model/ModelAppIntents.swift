import AppIntents

extension Model {
    func setupAppIntents() {
        AppDependencyManager.shared.add(dependency: self)
    }
}
