import SwiftUI

struct WidgetWizardBingoCardSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var bingoCard: SettingsWidgetBingoCard
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            BingCardWidgetTextView(value: $bingoCard.cellsText)
                .onChange(of: bingoCard.cellsText) { _ in
                    bingoCard.cellsTextChanged()
                }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
