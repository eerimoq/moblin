import SwiftUI

struct WidgetWizardBingoCardSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var bingoCard: SettingsWidgetBingoCard
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            BingCardWidgetSquaresView(value: $bingoCard.squaresText)
                .onChange(of: bingoCard.squaresText) { _ in
                    bingoCard.squaresTextChanged()
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
