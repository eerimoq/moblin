import SwiftUI

struct QuickButtonSettingsIconView: View {
    let model: Model
    let name: String
    let type: SettingsQuickButtonType

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 15))
            .frame(width: 30, height: 30)
            .foregroundColor(.white)
            .background(model.getGlobalButton(type: type)?.backgroundColor.color() ?? .clear)
            .clipShape(Circle())
    }
}
