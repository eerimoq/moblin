import SwiftUI

struct WidgetWizardImageSettingsView: View {
    let model: Model
    let database: Database
    let widget: SettingsWidget
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool
    @State var image: UIImage?

    var body: some View {
        Form {
            WidgetImagePickerView(model: model, widget: widget, image: $image, sizeScale: 5)
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(image == nil)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CreateWidgetWizardToolbar(presentingCreateWizard: $presentingCreateWizard)
        }
    }
}
