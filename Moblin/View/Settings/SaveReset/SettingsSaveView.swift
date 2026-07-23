import SwiftUI

struct SettingsSaveView: View {
    let model: Model
    @State var showSaved: Bool = false

    var body: some View {
        HCenter {
            if showSaved {
                Text("Saved 😅")
            } else {
                Button("Save settings") {
                    model.storeSettings()
                    showSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSaved = false
                    }
                }
            }
        }
    }
}
