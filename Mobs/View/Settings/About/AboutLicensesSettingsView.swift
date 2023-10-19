import LicenseList
import SwiftUI

struct AboutLicensesSettingsView: View {
    var toolbar: Toolbar

    var body: some View {
        LicenseListView()
            .navigationTitle("Licenses")
            .toolbar {
                toolbar
            }
    }
}
